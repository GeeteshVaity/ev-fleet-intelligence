# AWS deployment guide

This runbook deploys the EV Fleet Intelligence platform from an empty AWS
account to a working environment. It uses the simplest production-shaped
architecture that matches the current codebase:

```text
Flutter Android/web client
          |
          | HTTPS
          v
Route 53 -> ACM certificate -> Application Load Balancer
                                      |
                                      v
                           EC2 Spring Boot API
                                      |
                                      v
                              RDS PostgreSQL

Flutter web static files -> S3 -> CloudFront
Station images           -> S3 (private bucket + presigned URLs)
User authentication      -> Amazon Cognito
Logs and alarms          -> CloudWatch
```

The guide intentionally separates what is currently deployable from what must
be completed before calling the system production-ready.

## 0. Read this before deploying

The repository currently has these limitations:

1. Local development uses `X-User-Sub` as an identity boundary. This is not
   production authentication. Before production, validate Cognito JWTs in
   Spring Security and derive the user subject from the validated token.
2. The active Flutter demo entry point still contains in-memory home, station,
   booking, and vehicle data. The remote repositories are available, but the
   active screens must be migrated to use them before a production client can
   be considered fully connected.
3. Station image upload currently returns local metadata. Implement an S3
   presigned upload adapter before enabling image uploads in production.
4. The backend currently uses Hibernate schema auto-update locally. Production
   should use versioned database migrations and `ddl-auto=validate`.
5. The commands below use placeholders. Never commit passwords, private keys,
   Cognito secrets, or AWS access keys.

Do not expose an EC2 instance directly to the internet when an ALB can be used.
Do not put a database in a public subnet.

## 1. AWS account prerequisites

Create or obtain:

- An AWS account with billing enabled.
- A domain name, for example `example.com`.
- A separate AWS account or at least separate AWS resources for staging and
  production.
- An administrator identity for initial setup.
- A local installation of:
  - AWS CLI v2
  - Git
  - Java 21
  - Maven or the repository Maven wrapper
  - Flutter and Dart
  - OpenSSL
  - SSH client

Configure the AWS CLI with an IAM user or, preferably, IAM Identity Center:

```powershell
aws configure sso
aws sts get-caller-identity
aws configure list
```

Set a deployment region and keep it consistent. The examples below use
`ap-south-1`; change it everywhere if another region is required:

```powershell
$env:AWS_REGION = "ap-south-1"
aws configure set region $env:AWS_REGION
```

Enable MFA on all human identities. Do not use the root user for deployments.
Create a billing alarm before creating infrastructure.

## 2. Choose names and record them

Use globally unique names for S3 buckets and stable names for other resources.
Example naming:

```text
Project:       ev-fleet-intelligence
Environment:   production
AWS region:    ap-south-1
API host:      api.example.com
Web host:      app.example.com
Database:      evfleetdb
DB user:       evfleet_app
```

Record these values in a password manager or a secure deployment system, not
in Git:

- AWS account ID
- Region
- VPC ID and subnet IDs
- RDS endpoint
- EC2 instance ID and private IP
- ALB DNS name
- API and web DNS names
- Cognito user pool ID
- Cognito app client ID
- S3 bucket names

## 3. Create the network

Use the default VPC only for a temporary proof of concept. For production,
create a dedicated VPC with:

- CIDR: `10.20.0.0/16`
- Two public subnets in different Availability Zones for the ALB.
- Two private application subnets in different Availability Zones for EC2.
- Two private database subnets in different Availability Zones for RDS.
- Internet Gateway for public subnets.
- NAT Gateway for private application subnets if the backend needs outbound
  internet access.
- Route tables matching the subnet roles.

The AWS Console path is:

```text
VPC -> Your VPCs -> Create VPC
VPC -> Subnets -> Create subnet
VPC -> Internet gateways -> Create and attach
VPC -> NAT gateways -> Create
VPC -> Route tables -> Create and associate
```

For a first deployment, the VPC wizard can create the public/private subnet
layout. Confirm that the RDS subnets are private and have no route to an
Internet Gateway.

## 4. Create security groups

Create separate security groups with only these inbound rules:

### ALB security group

| Protocol | Port | Source |
|---|---:|---|
| TCP | 80 | `0.0.0.0/0` |
| TCP | 443 | `0.0.0.0/0` |

### EC2 API security group

| Protocol | Port | Source |
|---|---:|---|
| TCP | 8080 | ALB security group only |
| SSH 22 | Your fixed administrator IP only, temporary |

### RDS security group

| Protocol | Port | Source |
|---|---:|---|
| TCP | 5432 | EC2 API security group only |

Never allow `5432` from `0.0.0.0/0`. Remove or restrict SSH after validating
Session Manager access.

## 5. Create the production database in RDS

In the AWS Console:

```text
RDS -> Databases -> Create database
```

Recommended settings:

1. Engine: PostgreSQL.
2. Version: use a supported version compatible with the local project.
3. Template: Production.
4. Availability: Multi-AZ for production.
5. DB instance: start with a small burstable class and scale after observing
   CPU and connections.
6. Storage: General Purpose SSD, autoscaling enabled with a safe maximum.
7. DB identifier: `ev-fleet-production`.
8. Master username: do not use `postgres`; use an administrative name.
9. Password: generate and store it in AWS Secrets Manager.
10. VPC: the dedicated VPC.
11. DB subnet group: the two private database subnets.
12. Public access: `No`.
13. VPC security group: the RDS security group.
14. Initial database name: `evfleetdb`.
15. Encryption: enabled with the AWS managed key initially or a customer
    managed KMS key if required.
16. Automated backups: enabled, with a retention period appropriate for the
    business.
17. Deletion protection: enabled for production.
18. Log exports: PostgreSQL logs and upgrade logs to CloudWatch.

Store these values in Secrets Manager as a JSON secret named, for example,
`ev-fleet/production/database`:

```json
{
  "host": "replace-with-rds-endpoint",
  "port": 5432,
  "database": "evfleetdb",
  "username": "evfleet_app",
  "password": "replace-with-generated-password"
}
```

After RDS becomes available, copy its endpoint. The JDBC URL will be:

```text
jdbc:postgresql://<rds-endpoint>:5432/evfleetdb
```

Do not manually open the database to the internet to test it. Test from the
private EC2 network or use a controlled bastion/Session Manager workflow.

## 6. Prepare database schema migrations

Before production data exists:

1. Add Flyway or Liquibase to `backend/pom.xml`.
2. Create an initial migration representing the current entities and indexes.
3. Run migrations against a disposable RDS staging database.
4. Change production configuration to:

```properties
spring.jpa.hibernate.ddl-auto=validate
spring.jpa.show-sql=false
spring.jpa.properties.hibernate.format_sql=false
```

5. Never use `ddl-auto=update` against production.
6. Back up the database before every migration.

If migration tooling has not been added yet, use a staging database for the
first deployment only and treat that deployment as a pre-production
environment, not a finished production release.

## 7. Create Cognito authentication

In the AWS Console:

```text
Cognito -> User pools -> Create user pool
```

Configure:

1. Sign-in identifier: email.
2. Required attributes: email and any profile fields the app needs.
3. Password policy suitable for the application.
4. MFA according to the product security requirement.
5. Email delivery: Cognito managed email for development, SES for production.
6. User pool name: `ev-fleet-production`.
7. Create an app client without a client secret for the public Flutter app.
8. Enable authorization code grant with PKCE.
9. Configure scopes such as `openid`, `email`, and `profile`.
10. Add exact callback URLs for the web app and mobile redirect scheme.
11. Add exact sign-out URLs.
12. Configure a Cognito domain, for example
    `auth.example.com` or an AWS-generated Cognito domain.

Record:

```text
COGNITO_USER_POOL_ID=ap-south-1_xxxxxxxx
AWS_REGION=ap-south-1
COGNITO_APP_CLIENT_ID=xxxxxxxx
COGNITO_REDIRECT_URI=<exact-callback-url>
```

### Backend Cognito validation

The backend must validate the JWT issuer, signature, expiration, audience/client
ID, and token use. Add Spring Security resource-server JWT support and configure:

```text
Issuer:
https://cognito-idp.<region>.amazonaws.com/<user-pool-id>
```

Then replace every use of the caller-supplied `X-User-Sub` header in production
authorization logic with the authenticated JWT subject. A client must never be
able to choose another user's subject by changing a header.

Keep the `X-User-Sub` path only behind an explicit local-development profile if
it is still needed for tests.

## 8. Create IAM roles

Create an EC2 instance role, for example `ev-fleet-api-production-role`, with
least-privilege permissions:

- Read only the specific database secret in Secrets Manager.
- Read/write only the required objects in the private station-image S3 bucket.
- Write application logs and metrics to CloudWatch.
- Use Systems Manager if SSH is being replaced.
- No administrator access.

Create separate roles for CI/CD and operations. Do not put long-lived AWS
access keys in the EC2 filesystem or Flutter application.

## 9. Create the private S3 image bucket

Create a bucket in the selected region:

```text
ev-fleet-production-station-images-<account-id>
```

Configure:

1. Block all public access.
2. Bucket owner enforced object ownership.
3. Default encryption with SSE-S3 or SSE-KMS.
4. Versioning enabled.
5. Lifecycle rules for abandoned uploads and old versions.
6. CORS limited to the deployed web origin if browser uploads are used.
7. Bucket policy allowing only the EC2 role and the required upload flow.

The backend should generate short-lived presigned PUT/GET URLs. Do not return
AWS access keys to the Flutter app.

## 10. Create the EC2 backend host

In the AWS Console:

```text
EC2 -> Instances -> Launch instance
```

Recommended starting settings:

1. Ubuntu LTS or Amazon Linux 2023.
2. A current general-purpose ARM or x86 instance appropriate for the selected
   Java build.
3. Dedicated VPC private application subnet.
4. No public IPv4 address in the production design.
5. EC2 API security group.
6. Instance role created above.
7. Encrypted EBS volume.
8. Detailed monitoring if required.
9. Systems Manager enabled.

For a simpler first deployment, put the EC2 instance in a public subnet but
allow port 8080 only from the ALB and use Session Manager instead of opening
SSH. The RDS database must remain private.

Connect through Session Manager:

```text
EC2 -> Instances -> select instance -> Connect -> Session Manager
```

Install Java 21, Git, and required runtime tools. On Ubuntu, the exact package
name can vary by release; verify:

```bash
java -version
```

Create a dedicated application user and directories:

```bash
sudo useradd --system --home /opt/ev-fleet --shell /usr/sbin/nologin evfleet
sudo mkdir -p /opt/ev-fleet/releases /opt/ev-fleet/current
sudo chown -R evfleet:evfleet /opt/ev-fleet
```

Build the backend in CI or on a controlled build machine:

```powershell
Set-Location .\backend
.\mvnw.cmd clean package -DskipTests
```

Copy the resulting JAR to the EC2 release directory. Do not build from an
unreviewed working tree on the production server.

## 11. Configure the backend on EC2

Create a root-owned environment file such as:

```text
/etc/ev-fleet/production.env
```

Example values:

```properties
SPRING_DATASOURCE_URL=jdbc:postgresql://<rds-endpoint>:5432/evfleetdb
SPRING_DATASOURCE_USERNAME=evfleet_app
SPRING_DATASOURCE_PASSWORD=<read-from-secrets-manager>
SERVER_PORT=8080
SPRING_JPA_HIBERNATE_DDL_AUTO=validate
SPRING_JPA_SHOW_SQL=false
```

Prefer fetching the secret at startup through the AWS SDK or a secrets
sidecar instead of writing the password to disk. If an environment file is
used temporarily:

```bash
sudo chown root:root /etc/ev-fleet/production.env
sudo chmod 600 /etc/ev-fleet/production.env
```

Create a systemd service:

```ini
[Unit]
Description=EV Fleet Intelligence API
After=network-online.target
Wants=network-online.target

[Service]
User=evfleet
Group=evfleet
WorkingDirectory=/opt/ev-fleet/current
EnvironmentFile=/etc/ev-fleet/production.env
ExecStart=/usr/bin/java -jar /opt/ev-fleet/current/backend.jar
SuccessExitStatus=143
Restart=always
RestartSec=10
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

Start and inspect it:

```bash
sudo systemctl daemon-reload
sudo systemctl enable ev-fleet-api
sudo systemctl start ev-fleet-api
sudo systemctl status ev-fleet-api
sudo journalctl -u ev-fleet-api -n 100 --no-pager
```

Add a simple authenticated-free readiness endpoint before production, such as
`/actuator/health`, and expose only the health endpoint to the load balancer.
Do not use a data endpoint as the health check.

## 12. Create the Application Load Balancer

In the AWS Console:

```text
EC2 -> Load Balancers -> Create -> Application Load Balancer
```

Configure:

1. Internet-facing.
2. Two public subnets in different Availability Zones.
3. ALB security group.
4. Target group using HTTP port `8080`.
5. Target type: instance or IP.
6. Health check path: `/actuator/health`.
7. Listener 80: redirect to HTTPS.
8. Listener 443: forward to the backend target group.
9. Attach an ACM certificate.

Test the ALB DNS name before adding DNS:

```powershell
curl.exe -i https://<alb-dns-name>/actuator/health
```

## 13. Configure HTTPS and DNS

In AWS Certificate Manager:

1. Request a public certificate for `api.example.com`.
2. Choose DNS validation.
3. Add the provided validation CNAME record to Route 53.
4. Wait for the certificate to become `Issued`.
5. Attach it to the ALB HTTPS listener.

In Route 53:

1. Create or import the hosted zone for `example.com`.
2. Set the registrar name servers to the Route 53 name servers.
3. Create an alias A record:

```text
api.example.com -> ALB
```

Use HTTPS only in all Flutter release builds:

```text
https://api.example.com
```

## 14. Deploy Flutter web, if required

Create a public web bucket for the static frontend. Keep it separate from the
private station-image bucket:

```text
ev-fleet-production-web-<account-id>
```

Build the web client:

```powershell
Set-Location .\evfleet_mobile
flutter pub get
flutter build web --release `
  --dart-define=API_BASE_URL=https://api.example.com `
  --dart-define=AWS_REGION=ap-south-1 `
  --dart-define=COGNITO_USER_POOL_ID=ap-south-1_xxxxxxxx `
  --dart-define=COGNITO_APP_CLIENT_ID=xxxxxxxx `
  --dart-define=COGNITO_REDIRECT_URI=https://app.example.com/auth/callback
```

Upload the build:

```powershell
aws s3 sync .\build\web s3://ev-fleet-production-web-<account-id> `
  --delete --cache-control "public,max-age=31536000,immutable"
```

Use CloudFront in front of the bucket. Configure:

1. Origin access control.
2. Private S3 bucket; no public bucket policy.
3. Default root object: `index.html`.
4. Custom error responses mapping 403 and 404 to `/index.html` for Flutter
   client-side routes.
5. ACM certificate in `us-east-1` for the CloudFront distribution.
6. Alternate domain name: `app.example.com`.
7. HTTPS redirect.
8. Compression enabled.

Create a Route 53 alias:

```text
app.example.com -> CloudFront distribution
```

After each release, invalidate cached HTML:

```powershell
aws cloudfront create-invalidation `
  --distribution-id <distribution-id> `
  --paths "/index.html" "/flutter_bootstrap.js"
```

## 15. Build and distribute Android

Before creating a release build:

1. Complete Cognito PKCE redirect handling in Android.
2. Configure Android signing with a release keystore.
3. Store the keystore and passwords outside Git.
4. Configure the Android application ID and version.
5. Add the production HTTPS API URL.
6. Test against staging before production.

Build an APK for internal testing:

```powershell
Set-Location .\evfleet_mobile
flutter build apk --release `
  --dart-define=API_BASE_URL=https://api.example.com `
  --dart-define=AWS_REGION=ap-south-1 `
  --dart-define=COGNITO_USER_POOL_ID=ap-south-1_xxxxxxxx `
  --dart-define=COGNITO_APP_CLIENT_ID=xxxxxxxx `
  --dart-define=COGNITO_REDIRECT_URI=<mobile-redirect-uri>
```

Build an Android App Bundle for Google Play:

```powershell
flutter build appbundle --release `
  --dart-define=API_BASE_URL=https://api.example.com `
  --dart-define=AWS_REGION=ap-south-1 `
  --dart-define=COGNITO_USER_POOL_ID=ap-south-1_xxxxxxxx `
  --dart-define=COGNITO_APP_CLIENT_ID=xxxxxxxx `
  --dart-define=COGNITO_REDIRECT_URI=<mobile-redirect-uri>
```

Never embed AWS IAM credentials in the APK. The Cognito app client ID is
public; client secrets and AWS access keys are not.

## 16. Configure monitoring and operations

Create CloudWatch alarms for:

- ALB 5xx responses.
- ALB unhealthy targets.
- EC2 status checks and CPU.
- RDS CPU, storage, free memory, connections, and free storage.
- API latency.
- Estimated AWS charges.

Configure:

1. EC2 application logs to CloudWatch Logs.
2. ALB access logs to an S3 bucket.
3. RDS PostgreSQL logs to CloudWatch.
4. SNS email or incident notification topics.
5. A log retention period.
6. RDS automated backups and periodic restore tests.
7. EC2 AMI or launch-template recovery plan.

Document how to:

- Roll back to the previous JAR.
- Roll back a Flutter web release.
- Restore an RDS snapshot.
- Rotate the database password.
- Rotate Cognito settings.
- Revoke compromised sessions.
- Replace an unhealthy EC2 instance.

## 17. Production deployment checklist

### Security

- [ ] MFA enabled for all human AWS identities.
- [ ] No secrets committed to Git.
- [ ] RDS is private and encrypted.
- [ ] RDS security group allows only the API security group.
- [ ] EC2 has an instance role with least privilege.
- [ ] S3 buckets block public access unless a public static-site policy is
      intentionally replaced by CloudFront origin access control.
- [ ] API is HTTPS-only through the ALB.
- [ ] Cognito JWT validation is enabled in the backend.
- [ ] `X-User-Sub` is not trusted in production.
- [ ] CORS allows only the deployed web origins.
- [ ] Database migrations are versioned.

### Application

- [ ] Backend tests pass.
- [ ] Flutter analyzer and tests pass.
- [ ] Remote Flutter repositories are wired into the active screens.
- [ ] Profile creation, vehicle creation, station creation, station browsing,
      booking, cancellation, and sign-out were tested against staging.
- [ ] Station images use S3 presigned URLs.
- [ ] Health endpoint returns healthy only when dependencies are ready.
- [ ] Error responses do not expose stack traces or secrets.

### Release

- [ ] Production build uses `https://api.example.com`.
- [ ] Android signing is configured outside Git.
- [ ] Cognito callback and sign-out URLs exactly match the deployed clients.
- [ ] CloudFront SPA fallback works on a direct route refresh.
- [ ] DNS and TLS certificates are valid.
- [ ] Backups and alarms were tested.

## 18. End-to-end verification

From a machine outside the VPC:

```powershell
curl.exe -i https://api.example.com/actuator/health
curl.exe -i https://api.example.com/api/stations
```

The stations endpoint should return `401` once Cognito enforcement is enabled
unless it is intentionally public. Test authenticated calls with a real
Cognito access token; never test production with a fabricated subject header.

Verify the following flows:

1. Register a new Cognito user.
2. Sign in through the web or Android client.
3. Confirm the backend receives the validated Cognito subject.
4. Complete vehicle-owner onboarding.
5. Create and retrieve a vehicle.
6. Browse stations.
7. Create a booking and verify server-side conflict handling.
8. Cancel a booking.
9. Sign out and confirm protected routes are inaccessible.
10. Sign in as a different user and confirm ownership isolation.
11. Upload and retrieve a station image through presigned URLs.
12. Inspect CloudWatch logs and alarms.

## 19. Deployment commands summary

Backend build:

```powershell
Set-Location .\backend
.\mvnw.cmd clean test package
```

Flutter checks:

```powershell
Set-Location .\evfleet_mobile
flutter pub get
flutter analyze
flutter test
```

Flutter web build:

```powershell
flutter build web --release --dart-define=API_BASE_URL=https://api.example.com
```

S3 upload:

```powershell
aws s3 sync .\build\web s3://<web-bucket> --delete
```

## 20. Remove the environment

Deletion is destructive. Export data and confirm the target account and
region before proceeding.

1. Disable the CloudFront distribution and wait for deletion if removing it.
2. Remove Route 53 records and hosted zone only if the domain is no longer
   used.
3. Delete the ALB and target group.
4. Terminate EC2 instances and delete unused EBS volumes.
5. Delete the RDS instance only after taking a final snapshot and disabling
   deletion protection.
6. Delete NAT gateways to stop hourly charges.
7. Delete unused Elastic IP addresses.
8. Empty and delete S3 buckets only after confirming backups are not needed.
9. Delete Cognito resources if the user accounts are no longer required.
10. Remove unused security groups, IAM roles, CloudWatch logs, alarms, and
    SNS topics.
11. Verify billing and Cost Explorer after cleanup.

## Related documentation

- [Local app testing](./LOCAL_APP_TESTING.md)
- [Flutter Android setup](./FLUTTER_ANDROID_SETUP.md)
- [Root README](./README.md)
- [Cognito implementation notes](./Implementation.md)
