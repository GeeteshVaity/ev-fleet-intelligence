# Production configuration

The backend receives secrets through the runtime environment or AWS Secrets
Manager. Do not put these values in GitHub, Flutter assets, `.env` files
committed to the repository, or application properties.

## Backend runtime variables

Set these on the Spring Boot host (or map them from Secrets Manager):

| Variable | Required | Example/value source |
|---|---:|---|
| `SPRING_PROFILES_ACTIVE` | yes | `prod` |
| `DB_URL` | yes | `jdbc:postgresql://<RDS_ENDPOINT>:5432/evfleetdb` |
| `DB_USERNAME` | yes | RDS application user, not the master user |
| `DB_PASSWORD` | yes | Secrets Manager database secret |
| `COGNITO_ENABLED` | yes | `true` |
| `COGNITO_ISSUER_URI` | yes | `https://cognito-idp.<region>.amazonaws.com/<user-pool-id>` |
| `COGNITO_CLIENT_ID` | yes | Cognito public app client ID |
| `FRONTEND_ORIGIN` | yes | Exact HTTPS web origin, if web is enabled |
| `AWS_REGION` | yes | RDS/S3 deployment region, for example `ap-south-1` |
| `S3_ENABLED` | yes | `true` |
| `S3_BUCKET` | yes | Private station-image bucket name |
| `S3_PRESIGN_EXPIRY_SECONDS` | no | `900` |
| `DB_POOL_MAX_SIZE` | no | Start with `10`, then tune from RDS metrics |

Use an EC2 instance profile, ECS task role, or equivalent workload identity
for S3. Do not set `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY` on the host
unless the deployment platform cannot use an IAM role.

## Charging-provider client configuration

The public values are passed during release builds and are safe to ship:

```text
API_BASE_URL=https://api.example.com
AWS_REGION=ap-south-1
COGNITO_USER_POOL_ID=ap-south-1_xxxxxxxx
COGNITO_APP_CLIENT_ID=public-client-id
DEMO_MODE=false
```

Use `frontend/.env.example` as the template for the Flutter web/client
configuration. Never add database credentials, Cognito client secrets, AWS
access keys, or JWT signing keys to Flutter configuration.

For the charging-provider app, pass the same public values with
`--dart-define-from-file=mobile/charging_provider/env/production.json` (create
that untracked file locally) or individual `--dart-define` flags. The app no
longer contains a deployed API address or Cognito identifiers as source-code
defaults.

## GitHub Actions production variables

Create these as GitHub **Environment variables** under the `production`
environment:

```text
AWS_REGION=ap-south-1
AWS_DEPLOY_ROLE_ARN=arn:aws:iam::<account-id>:role/<github-actions-role>
ECR_REPOSITORY=ev-fleet-intelligence-api
```

The deployment workflow uses GitHub OIDC. Configure the AWS role trust policy
for this repository and the `production` environment; do not create long-lived
AWS keys as repository secrets.
