# EV Fleet Intelligence: AWS production deployment runbook

This runbook takes the **charging-provider application and Spring Boot API**
from a new AWS account to a live, HTTPS-protected deployment with PostgreSQL,
Cognito, private station-image storage, monitoring, and GitHub Actions
deployment.

The procedure uses the deployment artifacts currently in this repository:

- Spring Boot API in `backend/`
- Flyway migrations in `backend/src/main/resources/db/migration/`
- Java 21 container in `backend/Dockerfile`
- GitHub Actions build in `.github/workflows/ci.yml`
- Manual, approval-gated production deployment in
  `.github/workflows/deploy-production.yml`
- Flutter charging-provider client in `mobile/charging_provider/`

The vehicle-user Flutter application is intentionally not part of this
deployment. Do not deploy it until it is complete.

## 1. Target architecture

```text
Charging-provider Flutter app
        |
        | HTTPS + Cognito access token
        v
Route 53 -> ACM -> internet-facing ALB
                         |
                         v
              EC2 Docker host in private app subnet
                         |
              +----------+----------+
              |                     |
              v                     v
       RDS PostgreSQL       Private S3 image bucket
              |
              v
        Flyway migrations

GitHub Actions -> OIDC -> AWS IAM role -> ECR -> SSM -> EC2
                                                |
                                                v
                                      CloudWatch / ALB health checks
```

### Production principles

1. The API is reachable only through the ALB. Do not expose port `8080`
   publicly.
2. RDS is private and accepts traffic only from the API security group.
3. The S3 image bucket is private. The API creates short-lived presigned PUT
   URLs.
4. Cognito access tokens are validated by Spring Security. Never trust a
   caller-supplied user ID or subject header.
5. Production uses `ddl-auto=validate`; Flyway is the only schema change
   mechanism.
6. GitHub Actions uses OIDC and short-lived AWS role credentials. Do not add
   AWS access keys to GitHub secrets.
7. Passwords and database secrets belong in Secrets Manager or the deployment
   host environment, never in Git.

## 2. What is and is not included

### Included

- Cognito user-pool authentication.
- Provider profile, station, availability, booking, charging-session, and
  billing API deployment.
- PostgreSQL on Amazon RDS.
- Private S3 station-image bucket and presigned upload endpoint.
- EC2 Docker runtime behind an ALB.
- HTTPS with ACM and Route 53.
- GitHub Actions validation, ECR image publishing, and SSM deployment.
- Health checks, logs, backups, rollback, and smoke-test procedures.

### Current limitations to resolve before advertising all features

- The Flutter provider client must receive production values through
  `--dart-define-from-file`; it does not contain production credentials.
- The provider client still needs its image-picker flow wired to the backend
  `POST /api/stations/{stationId}/images/upload-url` contract if image upload
  is to be exposed in the UI.
- The API stores an image key after the client calls `POST /images`; production
  should add an S3 `HeadObject` verification before treating an object as
  complete.
- The deployment workflow deploys a new Docker container on one EC2 instance.
  For high availability, replace this runtime with ECS/Fargate or an EC2
  Auto Scaling Group before a strict zero-downtime requirement.

Do not silently enable a limited feature in production. Record accepted
limitations in the release approval.

## 3. Required tools and accounts

Install on the operator workstation:

- AWS CLI v2
- Git
- Java 21
- Docker
- Flutter/Dart compatible with `mobile/charging_provider/pubspec.yaml`
- An SSH client only if Session Manager is unavailable

Verify:

```powershell
aws --version
docker --version
java -version
flutter --version
git --version
```

Use an AWS IAM Identity Center user or another MFA-protected human identity:

```powershell
aws configure sso
aws sts get-caller-identity
aws configure list
```

Do not use the root user for daily work. Before creating resources:

1. Enable MFA for human identities.
2. Create an AWS Budget and billing alarm.
3. Select one region and use it consistently. Examples below use
   `ap-south-1`.
4. Use separate AWS resources/accounts for staging and production.

Set the operator region:

```powershell
$env:AWS_REGION = "ap-south-1"
aws configure set region $env:AWS_REGION
```

## 4. Choose names and record outputs

Choose names once. Keep the resulting IDs in a password manager or deployment
system, not in this repository.

```text
Project:                  ev-fleet-intelligence
Environment:              production
Region:                   ap-south-1
API hostname:             api.example.com
Web hostname (optional):  app.example.com
Database name:            evfleetdb
Database app user:        evfleet_app
ECR repository:           ev-fleet-intelligence-api
Image bucket:             ev-fleet-production-station-images-<account-id>
Web bucket (optional):    ev-fleet-production-web-<account-id>
```

Record:

- AWS account ID
- VPC and subnet IDs
- ALB name and DNS name
- EC2 instance ID
- RDS endpoint
- RDS security group ID
- Cognito user-pool ID and app-client ID
- S3 bucket names
- ACM certificate ARN
- Route 53 hosted-zone ID
- ECR repository URI
- GitHub OIDC role ARN

## 5. Create the network first

Use a dedicated VPC. Do not use the default VPC for the final production
environment.

Recommended layout:

| Component | Subnets | Internet route |
|---|---|---|
| ALB | Two public subnets in different AZs | Internet Gateway |
| EC2 API | Two private application subnets | NAT Gateway if outbound access is needed |
| RDS | Two private database subnets | No Internet Gateway route |

Example CIDR plan:

```text
VPC:             10.20.0.0/16
Public AZ-a:     10.20.1.0/24
Public AZ-b:     10.20.2.0/24
Private app AZ-a:10.20.11.0/24
Private app AZ-b:10.20.12.0/24
Private DB AZ-a: 10.20.21.0/24
Private DB AZ-b: 10.20.22.0/24
```

Console sequence:

1. VPC -> Create VPC.
2. Create six subnets in two Availability Zones.
3. Attach an Internet Gateway to the VPC.
4. Create public and private route tables.
5. Associate public subnets with the public route table.
6. Associate application and database subnets with private route tables.
7. Create a NAT Gateway in one public subnet if the private EC2 host needs
   outbound package/image access. Use one NAT Gateway per AZ when availability
   justifies the cost.
8. Create an RDS DB subnet group using both private database subnets.

Before continuing, verify that a database subnet has no route to an Internet
Gateway.

## 6. Create security groups

Create separate security groups. Reference security groups rather than broad
CIDR ranges wherever possible.

### `ev-fleet-alb-sg`

Inbound:

| Protocol | Port | Source |
|---|---:|---|
| TCP | 80 | `0.0.0.0/0` and `::/0` |
| TCP | 443 | `0.0.0.0/0` and `::/0` |

Outbound can remain the default restricted policy required by your
organization, but it must reach the API target on port `8080`.

### `ev-fleet-api-sg`

Inbound:

| Protocol | Port | Source |
|---|---:|---|
| TCP | 8080 | `ev-fleet-alb-sg` only |

Do not open `8080` to the Internet. Do not open SSH unless temporarily needed
from a fixed administrator IP. Prefer Session Manager.

### `ev-fleet-rds-sg`

Inbound:

| Protocol | Port | Source |
|---|---:|---|
| TCP | 5432 | `ev-fleet-api-sg` only |

Never permit PostgreSQL from `0.0.0.0/0`.

## 7. Create the Cognito user pool

The backend expects Cognito access-token JWTs and validates the issuer,
signature, expiry, token use, and client ID. The Flutter app needs a public
client; a mobile public client must not have a client secret.

Console sequence:

1. Cognito -> User pools -> Create user pool.
2. Name it `ev-fleet-production`.
3. Select email as the sign-in identifier.
4. Require email verification.
5. Configure a production password policy.
6. Choose MFA according to the product requirement.
7. Use Amazon SES for production email delivery after verifying the sending
   identity and production sending limits.
8. Create an app client with **no client secret**.
9. Enable only the flows required by the client. If the hosted UI is used,
   enable authorization-code flow with PKCE.
10. Configure exact callback and sign-out URLs. Do not use wildcard URLs.
11. Create a Cognito domain only if hosted UI/OAuth is used.
12. Record the user-pool ID, region, and public app-client ID.

Required values:

```text
AWS_REGION=ap-south-1
COGNITO_USER_POOL_ID=ap-south-1_xxxxxxxx
COGNITO_APP_CLIENT_ID=public-client-id
COGNITO_ISSUER_URI=https://cognito-idp.ap-south-1.amazonaws.com/ap-south-1_xxxxxxxx
```

Do not place `COGNITO_CLIENT_SECRET` in the Flutter app. If a hosted UI
integration ever requires a confidential client, keep it server-side and use a
separate client from the mobile public client.

## 8. Create IAM roles before compute

Create these roles with least privilege.

### 8.1 EC2 instance role

Attach:

- `AmazonSSMManagedInstanceCore`
- A custom policy allowing `secretsmanager:GetSecretValue` only for the
  production database secret.
- A custom S3 policy allowing only required operations under the station-image
  bucket/prefix.
- CloudWatch log delivery permissions if using the CloudWatch agent.
- ECR pull permissions for the single repository.

Example S3 permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:HeadObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::ev-fleet-production-station-images-ACCOUNT_ID/stations/*"
    }
  ]
}
```

Add `s3:ListBucket` only if the application requires it, and restrict it with
an `s3:prefix` condition. Do not attach `AdministratorAccess`.

### 8.2 GitHub Actions OIDC role

Create a role trusted by GitHub's OIDC provider:

```text
https://token.actions.githubusercontent.com
```

Trust only:

- The exact GitHub organization/user.
- The exact repository `GeeteshVaity/ev-fleet-intelligence`.
- The exact branch/environment subject, especially for production.

Allow only what the workflows need:

- ECR login and push to the API repository.
- `ssm:SendCommand` and `ssm:GetCommandInvocation` for the production EC2
  instance.
- Read-only ECR repository inspection.

Do not create long-lived `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY`
secrets for GitHub.

## 9. Create the private S3 station-image bucket

Create it in the same region as the backend:

```text
ev-fleet-production-station-images-<account-id>
```

Configure:

1. Block all public access.
2. Object Ownership: Bucket owner enforced.
3. Default encryption: SSE-S3 or SSE-KMS.
4. Versioning enabled.
5. Lifecycle rule to expire incomplete multipart uploads.
6. Lifecycle policy for old object versions.
7. Bucket policy allowing only the API workload role.
8. CORS only for exact production web origins if browser uploads are used.

The backend endpoint is:

```text
POST /api/stations/{stationId}/images/upload-url
```

Request:

```json
{ "contentType": "image/jpeg" }
```

Response:

```json
{
  "objectKey": "stations/123/<uuid>.jpg",
  "uploadUrl": "https://...",
  "expiresAt": "2026-..."
}
```

The client uploads bytes with `PUT` to `uploadUrl`, then persists the returned
object key through `POST /api/stations/{stationId}/images`.

## 10. Create the RDS PostgreSQL database

Console sequence:

1. RDS -> Databases -> Create database.
2. Engine: PostgreSQL.
3. Choose a currently supported PostgreSQL version compatible with the
   repository's PostgreSQL driver.
4. Use Production template for production.
5. Use Multi-AZ when the availability requirement justifies it.
6. Enable storage encryption.
7. Enable automated backups and point-in-time recovery.
8. Enable deletion protection.
9. Set a retention period appropriate for the business.
10. Set Public access to `No`.
11. Select the dedicated VPC and DB subnet group.
12. Attach `ev-fleet-rds-sg`.
13. Set initial database name to `evfleetdb`.
14. Create a master/admin credential in Secrets Manager.

Create a separate application database user with only the permissions needed by
the application. Do not run the API as the RDS master user.

Store the application credential in a Secrets Manager secret such as
`ev-fleet/production/database`:

```json
{
  "host": "ev-fleet-production.xxxxxx.ap-south-1.rds.amazonaws.com",
  "port": 5432,
  "database": "evfleetdb",
  "username": "evfleet_app",
  "password": "GENERATED_VALUE"
}
```

Do not commit this JSON or print it in CI logs.

## 11. Validate Flyway migrations on staging first

The repository currently contains:

```text
V1__create_initial_schema.sql
V2__add_provider_profile_fields.sql
V3__add_integrity_constraints.sql
```

The production profile uses:

```properties
spring.jpa.hibernate.ddl-auto=validate
spring.flyway.enabled=true
spring.flyway.baseline-on-migrate=false
```

### Empty staging database

1. Create a disposable RDS staging database or isolated PostgreSQL instance.
2. Configure the backend with `SPRING_PROFILES_ACTIVE=prod`.
3. Start the API once.
4. Confirm Flyway applies V1, V2, and V3.
5. Inspect the tables, constraints, indexes, and `flyway_schema_history`.
6. Run the backend regression tests and API smoke tests.

### Existing database

Do not set `ddl-auto=update` to force a deployment through. Instead:

1. Take a verified snapshot and logical backup.
2. Compare the existing schema with V1 and V2.
3. Resolve missing columns or incompatible data.
4. Perform any one-time reviewed Flyway baseline procedure.
5. Apply V3 only after checking existing rows satisfy its foreign keys and
   checks.
6. Restore the backup to a disposable database and rehearse the procedure.

A production startup failure caused by schema validation is safer than silently
changing production tables.

## 12. Create the EC2 Docker host

Use Amazon Linux 2023 or Ubuntu LTS in a private application subnet. Attach
the EC2 instance role from Section 8.

Recommended:

- Current-generation general-purpose instance sized from load testing.
- Encrypted EBS volume.
- No public IPv4 address in the final design.
- SSM agent enabled.
- Detailed monitoring enabled if required.

If the private subnet cannot reach ECR or package repositories, configure NAT
or the required VPC endpoints. Do not make RDS public to solve this.

Connect through Session Manager:

```text
EC2 -> Instances -> select instance -> Connect -> Session Manager
```

Install Docker and verify:

```bash
docker --version
aws sts get-caller-identity
aws ecr get-login-password --region ap-south-1
```

Create the runtime directory:

```bash
sudo mkdir -p /etc/ev-fleet-intelligence
sudo chmod 700 /etc/ev-fleet-intelligence
```

Create `/etc/ev-fleet-intelligence/backend.env` with the values listed in
Section 21. Restrict it:

```bash
sudo chown root:root /etc/ev-fleet-intelligence/backend.env
sudo chmod 600 /etc/ev-fleet-intelligence/backend.env
```

The deployment workflow expects Docker and this exact env-file path.

## 13. Create ECR

Create a private ECR repository:

```powershell
aws ecr create-repository `
  --repository-name ev-fleet-intelligence-api `
  --image-scanning-configuration scanOnPush=true `
  --image-tag-mutability IMMUTABLE `
  --region ap-south-1
```

Enable lifecycle cleanup for unneeded old images, but retain every image tag
used by an active deployment and its rollback target.

The image is built from:

```text
backend/Dockerfile
```

The image contains the compiled JAR only; database credentials and AWS
configuration are supplied at runtime.

## 14. Configure the backend runtime environment

The file `/etc/ev-fleet-intelligence/backend.env` must contain values like:

```text
SPRING_PROFILES_ACTIVE=prod
DB_URL=jdbc:postgresql://<RDS_ENDPOINT>:5432/evfleetdb
DB_USERNAME=evfleet_app
DB_PASSWORD=<DATABASE_PASSWORD>
DDL_AUTO=validate
FLYWAY_ENABLED=true
FLYWAY_BASELINE_ON_MIGRATE=false
COGNITO_ENABLED=true
COGNITO_ISSUER_URI=https://cognito-idp.ap-south-1.amazonaws.com/<USER_POOL_ID>
COGNITO_CLIENT_ID=<COGNITO_PUBLIC_APP_CLIENT_ID>
FRONTEND_ORIGIN=https://app.example.com
AWS_REGION=ap-south-1
S3_ENABLED=true
S3_BUCKET=ev-fleet-production-station-images-<ACCOUNT_ID>
S3_PRESIGN_EXPIRY_SECONDS=900
SERVER_PORT=8080
```

Use the EC2 role and Secrets Manager integration to populate
`DB_PASSWORD` rather than storing a permanent password when your operational
platform supports it. If the env-file is used, rotate it through a controlled
procedure and restart the container.

Never set:

```text
COGNITO_CLIENT_SECRET
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
JWT_SIGNING_KEY
```

The backend uses the EC2 role for AWS SDK access.

## 15. Build and run the first API container manually

From a reviewed checkout:

```powershell
Set-Location .\backend
.\mvnw.cmd clean verify
docker build -t ev-fleet-intelligence-api:local .
```

For CI, the image is tagged with the commit SHA. To perform a controlled
manual first deployment:

```bash
docker run -d \
  --name ev-fleet-api \
  --restart unless-stopped \
  --env-file /etc/ev-fleet-intelligence/backend.env \
  -p 127.0.0.1:8080:8080 \
  <ACCOUNT_ID>.dkr.ecr.ap-south-1.amazonaws.com/ev-fleet-intelligence-api:<TAG>
```

Inspect:

```bash
docker ps
docker logs --tail 200 ev-fleet-api
curl -i http://127.0.0.1:8080/actuator/health
```

Do not continue until the container starts, Flyway completes, and health
returns successfully.

## 16. Create the Application Load Balancer

Console sequence:

1. EC2 -> Load Balancers -> Create Application Load Balancer.
2. Scheme: Internet-facing.
3. Select both public subnets.
4. Attach `ev-fleet-alb-sg`.
5. Create a target group for instances or IPs on HTTP port `8080`.
6. Register the EC2 instance.
7. Health check protocol: HTTP.
8. Health check path: `/actuator/health`.
9. Success code: `200`.
10. Create port 80 listener that redirects to HTTPS.
11. Create port 443 listener that forwards to the target group after ACM is
    ready.

Verify the target becomes healthy. If it is unhealthy, check:

- The API container is bound to `127.0.0.1:8080` only when the ALB target is
  on the same host; for an ALB target, bind the container/API to the host
  interface inside the private network as required by the chosen target mode.
- The API security group allows traffic from the ALB security group.
- `/actuator/health` is reachable.
- Flyway and the database are ready.

Choose one consistent target design. If using an instance target, publish
container port `8080` on the instance private interface and allow only the ALB
security group to reach it.

## 17. Configure ACM and Route 53

### ACM

1. ACM -> Request certificate.
2. Request `api.example.com`.
3. Use DNS validation.
4. Create the validation CNAME in Route 53.
5. Wait for status `Issued`.
6. Attach the certificate to the ALB port 443 listener.

Request a separate certificate for `app.example.com` if hosting Flutter web.

### Route 53

1. Create or select the hosted zone for the domain.
2. Ensure the registrar uses the Route 53 name servers.
3. Create an alias A record:

```text
api.example.com -> Application Load Balancer
```

4. If hosting web, create:

```text
app.example.com -> CloudFront distribution
```

Test:

```powershell
curl.exe -i https://api.example.com/actuator/health
```

## 18. Optional Flutter web hosting

The charging-provider app is primarily mobile. If a web build is required:

1. Create a separate private S3-origin bucket for web assets.
2. Create a CloudFront distribution with the S3 bucket as an origin.
3. Use Origin Access Control; do not make the bucket public.
4. Configure the ACM certificate in `us-east-1` for CloudFront.
5. Configure the default root object and SPA error responses.
6. Point `app.example.com` to CloudFront.
7. Set backend `FRONTEND_ORIGIN=https://app.example.com`.

Build:

```powershell
Set-Location .\mobile\charging_provider
flutter build web --release `
  --dart-define-from-file=env\production.json
```

Upload only the `build/web/` contents to the web bucket. Do not upload
`production.json`.

## 19. Configure the charging-provider client

Create this local, untracked file:

```text
mobile/charging_provider/env/production.json
```

Contents:

```json
{
  "API_BASE_URL": "https://api.example.com",
  "AWS_REGION": "ap-south-1",
  "COGNITO_USER_POOL_ID": "ap-south-1_xxxxxxxx",
  "COGNITO_APP_CLIENT_ID": "public-client-id",
  "DEMO_MODE": "false"
}
```

Build the Android release:

```powershell
Set-Location .\mobile\charging_provider
flutter pub get
flutter analyze
flutter test
flutter build apk --release --dart-define-from-file=env\production.json
```

These are public client identifiers. Never put database passwords, AWS access
keys, Cognito client secrets, or JWT signing keys in this file. The API URL
must be HTTPS for release builds.

## 20. Configure GitHub Actions CI/CD

The current workflows are:

```text
.github/workflows/ci.yml
.github/workflows/deploy-production.yml
```

### 20.1 GitHub repository setup

1. Push the workflow files to the default branch.
2. In GitHub, create an environment named `production`.
3. Require reviewers for the `production` environment.
4. Restrict deployment branches to `main`.
5. Enable branch protection for `main`:
   - Require pull requests.
   - Require CI checks.
   - Require conversation resolution.
   - Do not allow force pushes.
6. Enable Dependabot/security alerts and secret scanning.

### 20.2 Add production environment variables

Under Repository -> Settings -> Environments -> `production` -> Variables, add:

```text
AWS_REGION=ap-south-1
AWS_ACCOUNT_ID=<12-digit-account-id>
AWS_DEPLOY_ROLE_ARN=arn:aws:iam::<account-id>:role/<github-oidc-role>
ECR_REPOSITORY=ev-fleet-intelligence-api
EC2_INSTANCE_ID=<production-ec2-instance-id>
```

These are identifiers, not passwords. Do not add long-lived AWS keys.

### 20.3 Verify the OIDC trust policy

The GitHub role must trust:

```text
token.actions.githubusercontent.com
```

Limit the `sub` condition to the repository and production environment. The
role must be unable to deploy arbitrary repositories or branches.

### 20.4 CI sequence

Every pull request and every push to `main`/`develop` should:

1. Check out the repository.
2. Start PostgreSQL.
3. Run backend Maven verification.
4. Run charging-provider `flutter pub get`, `flutter analyze`, and tests.

A push to `main` additionally:

1. Builds the backend JAR.
2. Builds the Docker image.
3. Logs in to ECR using OIDC.
4. Pushes an immutable commit-SHA tag.

The image is not production until the pull request checks pass.

### 20.5 Production deployment sequence

1. Merge the reviewed change to `main`.
2. Wait for `CI` to pass.
3. Confirm the image exists in ECR under the commit SHA.
4. Open Actions -> `Deploy production API`.
5. Enter the exact commit SHA as `image_tag`.
6. Start the workflow.
7. Approve the `production` environment when GitHub requests approval.
8. The workflow assumes the AWS OIDC role.
9. It sends an SSM command to EC2.
10. EC2 pulls the image, replaces the container, and starts it using the
    protected env file.
11. Verify the SSM command succeeded.
12. Verify the ALB target and health endpoint.
13. Run the smoke tests in Section 22.

Do not type secrets into workflow inputs or log commands that contain secrets.

## 21. Exact configuration locations

### AWS/EC2 runtime values

Edit or populate this file on the deployment host only:

```text
/etc/ev-fleet-intelligence/backend.env
```

Required values:

```text
SPRING_PROFILES_ACTIVE=prod
DB_URL=jdbc:postgresql://<RDS_ENDPOINT>:5432/evfleetdb
DB_USERNAME=<RDS_APP_USER>
DB_PASSWORD=<RDS_APP_PASSWORD>
COGNITO_ENABLED=true
COGNITO_ISSUER_URI=https://cognito-idp.<region>.amazonaws.com/<pool-id>
COGNITO_CLIENT_ID=<public-app-client-id>
FRONTEND_ORIGIN=https://<web-origin>
AWS_REGION=<region>
S3_ENABLED=true
S3_BUCKET=<private-image-bucket>
S3_PRESIGN_EXPIRY_SECONDS=900
```

The property mappings are in:

```text
backend/src/main/resources/application.properties
backend/src/main/resources/application-prod.properties
```

Do not put production secrets in those repository files.

### Local Flutter release values

Create locally and do not commit:

```text
mobile/charging_provider/env/production.json
```

Use the public values in Section 19.

### GitHub production variables

Set under the GitHub `production` environment:

```text
AWS_REGION
AWS_ACCOUNT_ID
AWS_DEPLOY_ROLE_ARN
ECR_REPOSITORY
EC2_INSTANCE_ID
```

### AWS Secrets Manager

Store the database password and, if used, the master/admin database credential
in Secrets Manager. The API must receive only the application user's
credential. Never store Flutter configuration or Cognito public IDs as
secrets.

## 22. First production smoke test

Run these checks in order after the first deployment.

### Infrastructure

- ALB target is healthy.
- EC2 instance is SSM managed.
- RDS is available and has no public access.
- RDS security group allows only the API security group.
- S3 block-public-access is enabled.
- CloudTrail and CloudWatch logging are enabled as required.

### API

```powershell
curl.exe -i https://api.example.com/actuator/health
```

Expected: HTTP `200` and a healthy response.

### Cognito

1. Register a provider through the Flutter app.
2. Verify the email in Cognito.
3. Sign in.
4. Confirm the app sends an access token, not an ID token, to the API.
5. Confirm an unauthenticated request to a protected endpoint returns `401`.
6. Confirm a provider cannot access another provider's station-management
   operations.

### Provider workflow

1. Complete provider profile onboarding.
2. Create a station.
3. Edit the station.
4. Add and remove availability windows.
5. Sign in as a vehicle owner only in a test environment and create a booking.
6. Accept or reject the booking as the provider.
7. Start and complete a charging session.
8. Confirm the server-calculated billing result.
9. If image upload is enabled, request a presigned URL, upload a test image,
   persist the object key, and verify the object remains private.

### Database

```sql
SELECT installed_rank, version, description, success
FROM flyway_schema_history
ORDER BY installed_rank;
```

All applied migrations must have `success = true`.

## 23. Logs, alarms, and operations

Monitor:

- ALB `HTTPCode_Target_5XX_Count`
- ALB target health
- EC2 CPU, memory, disk, and container restarts
- RDS CPU, storage, connections, free storage, and failed connections
- RDS backup status
- S3 4xx/5xx errors and object growth
- Cognito sign-in failures and throttling

Retain:

- ALB access logs if required.
- Application logs in CloudWatch.
- RDS PostgreSQL logs.
- CloudTrail management events.

Never log:

- Access tokens.
- Passwords.
- Database URLs containing credentials.
- Presigned URLs in long-term logs.
- AWS secret keys.

## 24. Rollback procedure

### Application rollback

1. Identify the last healthy commit SHA in ECR.
2. Open `Deploy production API`.
3. Enter that SHA as `image_tag`.
4. Approve the production environment.
5. Wait for SSM completion.
6. Verify ALB health and smoke tests.

Do not rebuild an old source branch with a different dependency lockfile when
an immutable image already exists.

### Database rollback

Flyway migrations are forward-only by default. Do not manually delete rows
from `flyway_schema_history` or downgrade production schema in place.

For a failed migration:

1. Stop promotion.
2. Preserve logs and migration status.
3. Restore the pre-migration RDS snapshot to a recovery instance or follow the
   approved forward-fix procedure.
4. Rehearse the repair on a restored copy.
5. Ship a new migration and application version.

## 25. Release checklist

Before release approval:

- [ ] Pull request CI passed.
- [ ] Backend tests passed against PostgreSQL.
- [ ] Charging-provider analyzer and tests passed.
- [ ] Docker image has an immutable commit-SHA tag.
- [ ] Image scan has no unaccepted critical findings.
- [ ] Production environment approval is configured.
- [ ] Cognito issuer and client ID are correct.
- [ ] RDS backup and restore procedure was tested.
- [ ] Flyway migrations were rehearsed on staging.
- [ ] S3 bucket is private and encrypted.
- [ ] EC2 has no unnecessary public exposure.
- [ ] ALB HTTPS listener and certificate are active.
- [ ] `FRONTEND_ORIGIN` is exact and not a wildcard.
- [ ] Flutter release uses HTTPS and production public identifiers.
- [ ] No secrets are present in Git, Flutter assets, logs, or workflow output.
- [ ] Rollback image SHA is recorded.
- [ ] Smoke tests passed after deployment.

## 26. Values that must never be committed

Never commit any of the following:

```text
DB_PASSWORD
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
COGNITO_CLIENT_SECRET
JWT signing/private keys
RDS master password
Secrets Manager JSON
Production access tokens
Private SSH keys
```

The repository should contain templates and documentation only. Public
identifiers such as the Cognito user-pool ID, public app-client ID, AWS region,
and HTTPS API URL may be passed to Flutter at build time, but keeping them in
an untracked release configuration is recommended.
