# EV Fleet Intelligence

Peer-to-peer EV charging: vehicle owners find nearby chargers and book slots;
household and commercial providers publish chargers and approve requests.

A Flutter mobile client (`frontend/`) talks to a Spring Boot API (`backend/`) backed by
PostgreSQL on Amazon RDS, with Amazon Cognito for authentication and email verification.

---

## What works today

| Area | Status |
|---|---|
| Cognito sign-up, email verification, sign-in, session restore, sign-out | Implemented |
| Role-based onboarding (vehicle owner / charger provider) with GPS station location | Implemented |
| Station discovery with server-side nearby search (radius ≤ 50 km) | Implemented |
| Availability windows, booking request, provider confirm/reject, seeker cancel | Implemented |
| Vehicle CRUD | Implemented |
| Charging sessions (start/complete) | API only — no UI |
| Station images | Metadata only — S3 uploads return `501` (see audit) |
| Provider-wide booking list, notifications, chat/contact | Not implemented |

The full severity-ranked list lives in [PROJECT_AUDIT.md](./PROJECT_AUDIT.md).

---

## Technology stack

| Layer | Technology |
|---|---|
| Mobile | Flutter 3.47, Dart, Riverpod, GoRouter, Material 3, Dio, geolocator, flutter_secure_storage, Amplify Auth |
| API | Java 21, Spring Boot 4.1.1, Spring Security (OAuth2 resource server), Spring Data JPA, Bean Validation, Flyway, Actuator |
| Database | PostgreSQL (Amazon RDS in production) |
| Auth | Amazon Cognito User Pool (email verification, public app client, no secret) |
| Hosting | Amazon EC2 + systemd behind an ALB; ACM for TLS |

---

## Repository structure

```
ev-fleet-intelligence/
├── README.md                  ← this file
├── PROJECT_AUDIT.md           ← audit findings, severities, statuses
├── AWS_DEPLOYMENT_GUIDE.md    ← EC2, RDS, Cognito, systemd runbook
├── LOCAL_APP_TESTING.md       ← end-to-end smoke tests
├── FLUTTER_ANDROID_SETUP.md   ← device/emulator setup
├── docs/
│   ├── API.md                 ← every endpoint, statuses, examples
│   └── ARCHITECTURE.md        ← components, flows, data model, failure modes
├── backend/
│   ├── README.md              ← backend setup and operations
│   ├── pom.xml
│   └── src/main/java/com/evfleet/backend/
│       ├── controller/        ← REST endpoints, DTO records, error advice
│       ├── service/           ← PlatformService (business rules) + thin services
│       ├── repository/        ← Spring Data JPA interfaces
│       ├── model/             ← JPA entities
│       └── security/          ← SecurityConfig, CurrentUser
└── frontend/
    ├── README.md              ← Flutter setup, routes, configuration
    ├── lib/app/app.dart       ← active app: router, providers, screens
    ├── lib/core/              ← config, network, errors, location, storage
    ├── lib/features/auth/     ← Cognito auth service + domain
    ├── lib/features/**        ← legacy feature tree (not wired to the active app)
    └── test/                  ← unit and widget tests
```

---

## Responsibilities

**Frontend** — present state, collect input, hold the Cognito session, request device
location, call the API, and render loading/empty/error states honestly. It never decides
authorization: role and ownership are enforced by the server, and no mock data replaces a
failed request (`DEMO_MODE` is explicit opt-in).

**Backend** — authenticate every request, derive identity from the JWT `sub`, enforce
role and ownership, validate input, run the booking rules, and persist to PostgreSQL.

---

## Data flow

```
Flutter screen → Riverpod provider → BackendApiService (Dio)
      → Authorization: Bearer <Cognito access token>
      → Spring Security (JWT validation) → Controller → PlatformService
      → Repository → PostgreSQL (RDS)
      → JSON → typed models → AsyncValue → widget states
```

A `401` clears the local session and returns the user to `/login`. A `409` is surfaced as
an actionable message (for example "Station is already booked").

---

## Authentication and onboarding

**New user** — `/register` (name, email, password) → Cognito sends a code →
`/verify-email` (confirm code, auto sign-in) → `/account-setup` (provider type, connector,
station location via GPS, or vehicle details) → `POST /api/vehicles|/api/stations` +
`PUT /api/users/me/onboarding` → `/home` (vehicle owner) or `/provider` (charging provider).

**Returning user** — `/login` → Cognito → `GET /api/auth/me`; a complete profile goes to
the dashboard, an incomplete one to `/account-setup`.

**Returning session** — the Cognito session is restored on launch and the backend profile
decides the destination; users never see registration again once onboarding is complete.

`onboardingCompleted` in the database is authoritative: the server refuses to set it
unless the profile has a role and at least one vehicle or station.

---

## AWS overview

| Resource | Purpose |
|---|---|
| Cognito User Pool | Sign-up, email verification, access tokens |
| EC2 + systemd | Runs the Spring Boot jar on port 8080 |
| RDS PostgreSQL | Application data; Flyway-managed schema |
| ALB + ACM | HTTPS termination for the API (**required before release**) |
| S3 | Not configured — station image uploads are not implemented |

Setup, security groups, SSL and the systemd unit are in
[AWS_DEPLOYMENT_GUIDE.md](./AWS_DEPLOYMENT_GUIDE.md). Cognito values are collected per
[frontend/README.md](./frontend/README.md#cognito-configuration).

---

## Prerequisites

- Java 21 and Maven 3.9+ (or the Maven wrapper in `backend/`)
- Flutter 3.47+ with the Android SDK (and an emulator or device)
- PostgreSQL 14+ locally, or an RDS instance
- An AWS account with a Cognito User Pool and a public app client

---

## Quick start

### Backend (Windows PowerShell)

```powershell
$env:DB_URL      = "jdbc:postgresql://localhost:5432/evfleetdb"
$env:DB_USERNAME = "postgres"
$env:DB_PASSWORD = "<local-password>"
$env:COGNITO_ENABLED    = "true"
$env:COGNITO_ISSUER_URI = "https://cognito-idp.<region>.amazonaws.com/<user-pool-id>"
Set-Location backend
.\mvnw.cmd spring-boot:run
```

Health: `http://localhost:8080/actuator/health`.

### Backend (Linux/EC2)

```bash
export DB_URL="jdbc:postgresql://<rds-endpoint>:5432/evfleetdb?sslmode=verify-full"
export DB_USERNAME="<user>" DB_PASSWORD="<secret>"
export COGNITO_ENABLED=true
export COGNITO_ISSUER_URI="https://cognito-idp.<region>.amazonaws.com/<user-pool-id>"
export FRONTEND_ORIGIN="https://<frontend-origin>"
java -jar backend/target/backend-0.0.1-SNAPSHOT.jar
```

### Frontend

```powershell
Set-Location frontend
flutter pub get
flutter run `
  --dart-define=API_BASE_URL=https://<api-host> `
  --dart-define=AWS_REGION=<region> `
  --dart-define=COGNITO_USER_POOL_ID=<pool-id> `
  --dart-define=COGNITO_APP_CLIENT_ID=<app-client-id>
```

`--dart-define=DEMO_MODE=true` loads the in-memory sample dataset; without it, a failed
request is always shown as an error.

---

## Testing

```powershell
# Backend: 39 unit/integration tests (H2 in PostgreSQL mode)
Set-Location backend
.\mvnw.cmd test

# Frontend: static analysis + widget tests
Set-Location ../frontend
flutter analyze
flutter test
```

Manual end-to-end checks (real Cognito user, device GPS, booking conflict) are described in
[LOCAL_APP_TESTING.md](./LOCAL_APP_TESTING.md). Anything requiring AWS, a device or live
credentials is listed as pending in the audit rather than claimed as passing.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Every API call returns `403` | `COGNITO_ENABLED` not set to `true` | Set it and restart (fail-safe by design) |
| `401` with a valid-looking token | ID token used instead of access token, wrong issuer, or expired session | Re-sign in; confirm `COGNITO_ISSUER_URI` matches the pool |
| Backend starts but cannot reach the database | `DB_URL`/`SPRING_DATASOURCE_URL` unset → defaults to `localhost:5432` | Set the variable; check the RDS security group |
| Startup fails with a Flyway "non-empty schema" error | Old schema without history table | `spring.flyway.baseline-on-migrate` is now enabled by default; confirm V1 matches |
| Hibernate `validate` fails in prod | Schema drift from `ddl-auto=update` | Compare with V1, migrate, then validate |
| `403 Assign a profile role…` | Legacy profile with `role = NULL` | Sign in once (auto-assign) or run the backfill SQL in the audit |
| Setup keeps reappearing after restart | `onboardingCompleted` is false server-side | Finish setup; the flag is read from `GET /api/auth/me` |
| Nearby search returns nothing | No active station in radius, or denied location permission | Widen the radius, check the device permission |
| Browser/client blocked by CORS | `FRONTEND_ORIGIN` mismatch | Set the exact origin, no wildcard |
| `501` from `images/upload-url` | S3 uploads are not configured | Expected; see the audit (TASK-13) |

---

## Documentation

- [PROJECT_AUDIT.md](./PROJECT_AUDIT.md) — findings, severities, task list, statuses
- [docs/API.md](./docs/API.md) — endpoint reference with examples
- [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) — components, flows, data model, failure modes
- [backend/README.md](./backend/README.md) — API setup and operations
- [frontend/README.md](./frontend/README.md) — Flutter setup, routes, configuration
- [AWS_DEPLOYMENT_GUIDE.md](./AWS_DEPLOYMENT_GUIDE.md) — infrastructure runbook
- [LOCAL_APP_TESTING.md](./LOCAL_APP_TESTING.md) — end-to-end smoke tests
