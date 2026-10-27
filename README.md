# EV Fleet Intelligence

Spring Boot REST API for the EV charging discovery and booking MVP described in
`EV_Charging_Platform_Project_Documentation_Updated-4.pdf`.

## Run locally

The backend uses PostgreSQL by default. Configure these environment variables
before starting it; no database password is committed:

```powershell
$env:SPRING_DATASOURCE_URL = "jdbc:postgresql://localhost:5432/evfleetdb"
$env:SPRING_DATASOURCE_USERNAME = "postgres"
$env:SPRING_DATASOURCE_PASSWORD = "<local-password>"
$env:COGNITO_ENABLED = "true"
$env:COGNITO_ISSUER_URI = "https://cognito-idp.<region>.amazonaws.com/<user-pool-id>"
Set-Location backend
.\mvnw.cmd spring-boot:run
```

For the complete backend/frontend setup, API smoke tests, Flutter device
commands, and troubleshooting steps, see
[LOCAL_APP_TESTING.md](./LOCAL_APP_TESTING.md).

For the complete AWS infrastructure and deployment runbook, see
[AWS_DEPLOYMENT_GUIDE.md](./AWS_DEPLOYMENT_GUIDE.md).

When `COGNITO_ENABLED=true`, Spring Security validates Cognito access-token JWTs
against `COGNITO_ISSUER_URI`. User-owned endpoints derive the subject from the
validated JWT; `X-User-Sub` is not accepted. Keep these values in the process
environment or deployment secret manager.

Run the Flutter app with build-time configuration (replace placeholders with
values from the Cognito console):

```powershell
Set-Location evfleet_mobile
flutter run `
  --dart-define=API_BASE_URL=http://localhost:8080 `
  --dart-define=AWS_REGION=<region> `
  --dart-define=COGNITO_USER_POOL_ID=<user-pool-id> `
  --dart-define=COGNITO_APP_CLIENT_ID=<app-client-id>
```

## API areas

The implementation exposes the documented `/api` routes for:

- `/users/me` profiles, vehicles, provider listings, and session history
- `/vehicles` CRUD
- `/stations`, `/stations/nearby`, availability, bookings, and station images
- `/bookings` request, cancellation, confirmation, rejection, and sessions
- `/sessions` simulated charging completion

Nearby search uses `latitude`, `longitude`, and `radiusKm` query parameters.
Availability and booking timestamps are ISO-8601 instants, for example
`2026-10-22T10:00:00Z`.

The image upload-url route currently returns a local metadata URL and an object
key. Configure an S3 presigned-upload adapter before production deployment.

## Verify

```powershell
Set-Location backend
.\mvnw.cmd test
```

Example authenticated profile setup (the bearer token must be a real Cognito
access token; do not use `X-User-Sub`):

```powershell
curl.exe -X POST http://localhost:8080/api/users/me `
  -H "Content-Type: application/json" -H "Authorization: Bearer <access-token>" `
  -d '{"fullName":"Demo User","email":"demo@example.com"}'
curl.exe http://localhost:8080/api/vehicles -H "Authorization: Bearer <access-token>"
```
