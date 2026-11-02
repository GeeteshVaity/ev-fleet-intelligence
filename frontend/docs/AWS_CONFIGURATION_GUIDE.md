# AWS Configuration Guide — EV Fleet Intelligence

This guide lists every AWS value the project needs, where to find it in the AWS Console, which file receives it,
and whether it is safe to ship in the mobile client.

Two rules that override everything else:

1. **Public identifiers may live in the client.** The API URL, the AWS region, the Cognito User Pool ID and the
   public app client ID are not secrets; they are visible in any app binary and that is normal.
2. **Real secrets never reach the client.** AWS access keys, database passwords, the Cognito app client secret and
   JWT signing material stay on the Spring Boot server (EC2 environment variables or SSM Parameter Store).

---

## 1. Value map

| Value | Where it goes | Console location | Client-safe? |
| --- | --- | --- | --- |
| `API_BASE_URL` | `frontend/.env` | EC2 → Instances → your instance → Public IPv4 / Elastic IP, or EC2 → Load balancers → DNS name | Yes |
| `AWS_REGION` | `frontend/.env` | Console region selector (top-right) while the User Pool is open | Yes |
| `COGNITO_USER_POOL_ID` | `frontend/.env` | Cognito → User pools → pool → Overview → User pool ID | Yes |
| `COGNITO_APP_CLIENT_ID` | `frontend/.env` | Cognito → User pools → pool → App integration → App clients → Client ID | Yes |
| `COGNITO_REDIRECT_URI` | `frontend/.env` (optional) | Cognito → App integration → Hosted UI (only if you enable a browser flow) | Yes |
| `COGNITO_ISSUER_URI` | **backend** env var | `https://cognito-idp.<region>.amazonaws.com/<user-pool-id>` | No — server only |
| `COGNITO_ENABLED` | **backend** env var (`true`) | — | No |
| `FRONTEND_ORIGIN` | **backend** env var | Exact origin of the web client, e.g. `http://localhost:3000` | No |
| `DB_USERNAME`, `DB_PASSWORD`, `SPRING_DATASOURCE_URL` | **backend** env vars | RDS → Databases → your instance → Configuration / Connectivity | No |
| `DDL_AUTO` | **backend** env var (`validate` in prod) | — | No |
| S3 bucket name / region | **backend** env vars | S3 → Buckets | Not configured yet (see §6) |

The frontend template is [`../.env.example`](../.env.example). Copy it to `frontend/.env` (git-ignored) and fill it in.

---

## 2. Amazon Cognito (authentication)

### 2.1 What must exist

- One **User Pool** with e-mail sign-in enabled.
- E-mail verification enabled (Cognito sends the code the app asks for on the verification screen).
- One **public app client** (no client secret) with:
  - **SRP** auth flow (`ALLOW_USER_SRP_AUTH`) — the app uses Amplify's `signIn`, which is SRP;
  - **USER_PASSWORD_AUTH** if you want username/password flows without SRP;
  - **no** `ALLOW_ADMIN_USER_PASSWORD_AUTH` (that requires a secret and is server-only);
  - an optional pre-sign-up Lambda if you want to auto-confirm test users.
- Password policy the app can satisfy: minimum 8 characters, upper, lower, number.

A mobile app **cannot** hold a client secret, so if the app client shows a secret, create a new app client without one.

### 2.2 Where each value comes from

| Value | Navigation |
| --- | --- |
| Region | The console region selector, e.g. `ap-south-1`. It must match the pool's prefix. |
| `COGNITO_USER_POOL_ID` | Cognito → User pools → *pool* → Overview → **User pool ID** (`ap-south-1_XXXXXXXXX`) |
| `COGNITO_APP_CLIENT_ID` | Cognito → User pools → *pool* → App integration → App clients → **Client ID** |

### 2.3 Verify

```powershell
# 1. The client received the values (no tokens, no secrets printed)
flutter run --dart-define-from-file=.env
# The app prints: [config] Configuration OK.

# 2. The pool exists and the client ID belongs to it
aws cognito-idp describe-user-pool-client `
  --user-pool-id ap-south-1_XXXXXXXXX `
  --client-id XXXXXXXXXXXXXXXXXXXXXXXXXX --region ap-south-1
```

Then sign up with a real e-mail; the verification screen must accept the code Cognito e-mails you.

---

## 3. Spring Boot on EC2 (JWT validation + CORS)

Required environment variables on the instance (never in the repo):

```sh
COGNITO_ENABLED=true
COGNITO_ISSUER_URI=https://cognito-idp.ap-south-1.amazonaws.com/ap-south-1_XXXXXXXXX
FRONTEND_ORIGIN=https://your-web-origin.example.com   # exact origin, never '*'
DB_USERNAME=evfleet
DB_PASSWORD=<from SSM Parameter Store / Secrets Manager>
SPRING_DATASOURCE_URL=jdbc:postgresql://<rds-endpoint>:5432/evfleetdb
DDL_AUTO=validate
SPRING_PROFILES_ACTIVE=prod
```

Notes verified in the code:

- `app.cognito.issuer-uri` / `app.cognito.enabled` map to `COGNITO_ISSUER_URI` / `COGNITO_ENABLED`.
  With `COGNITO_ENABLED=false` the JWT decoder is not configured, so **protected endpoints cannot work** —
  the app will look signed in (Cognito is fine) but every API call returns `401`.
- The issuer **must** be built from the same region and pool ID as the client, otherwise tokens fail with
  `invalid issuer` (this is the most common misconfiguration).
- CORS is driven by `FRONTEND_ORIGIN`; wildcard origins are refused by design. Native Android/iOS do not use CORS.
- The backend rejects Cognito **ID** tokens: the app must send the **access** token.

Verify:

```sh
curl -s https://<api-host>/actuator/health          # {"status":"UP"}
curl -s -o /dev/null -w '%{http_code}\n' https://<api-host>/api/stations   # 200 (public)
curl -s -o /dev/null -w '%{http_code}\n' https://<api-host>/api/bookings   # 401 without a token
```

---

## 4. Amazon RDS for PostgreSQL

| Parameter | Where |
| --- | --- |
| Endpoint & port | RDS → Databases → *instance* → Connectivity & security |
| Database name | `evfleetdb` (or your own; must match `SPRING_DATASOURCE_URL`) |
| Master user / password | Whatever you set at creation — store it in SSM Parameter Store, never in Git |
| Security group | Must allow `5432` **only** from the EC2 instance's security group |

`SPRING_PROFILES_ACTIVE=prod` enables Flyway (`spring.flyway.enabled=true`) and `ddl-auto=validate`, so the schema
comes from `backend/src/main/resources/db/migration/`. If Flyway has never run on this database, apply the migration
before starting the app.

Verify from the EC2 host:

```sh
psql "host=<rds-endpoint> port=5432 dbname=evfleetdb user=evfleet" -c '\dt'
```

---

## 5. HTTPS

Production traffic must be TLS:

- Put the API behind an ALB with an ACM certificate (or CloudFront in front of the ALB / EC2).
- `API_BASE_URL` must be `https://...` for release builds. The client refuses plaintext HTTP in release builds
  except for loopback hosts (`localhost`, `127.0.0.1`, `10.0.2.2`).
- The current default API origin is plain HTTP for the demo deployment; `android/app/src/main/res/xml/network_security_config.xml`
  whitelists only that host and local development hosts. Remove that exception once the API is behind TLS.
- For development on a physical device, `http://<LAN-IP>:8080` works because debug builds are not release builds.

---

## 6. Amazon S3 (not configured yet)

Everything about images is currently a stub:

- `POST /api/stations/{stationId}/images/upload-url` returns a placeholder (`"note": "Configure S3 presigned URLs before production"`),
  not a signed URL.
- No bucket name, region or credentials are referenced in `application*.properties`.
- The client has no image picker or upload path.

To finish it you need: an S3 bucket (S3 → Buckets), its region, and an EC2 IAM role with `s3:PutObject`/`s3:GetObject`
for that bucket. The signing code belongs on the server; the app should only ever receive short-lived presigned URLs.
**Do not** add AWS access keys to the Flutter app or to `.env`.

---

## 7. Checklist before a release build

- [ ] `frontend/.env` filled in and **not** committed (`git status` must not list it).
- [ ] `API_BASE_URL` is HTTPS.
- [ ] The app prints `[config] Configuration OK.` at startup.
- [ ] `COGNITO_ENABLED=true` and `COGNITO_ISSUER_URI` match the pool used by the app.
- [ ] `FRONTEND_ORIGIN` is the exact web origin (only if you ship the web build).
- [ ] `network_security_config.xml` no longer whitelists a plaintext host.
- [ ] No AWS keys, DB password or client secret exist anywhere under `frontend/`.
