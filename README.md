# EV Fleet Intelligence

Spring Boot REST API for the EV charging discovery and booking MVP described in
`EV_Charging_Platform_Project_Documentation_Updated-4.pdf`.

## Run locally

The backend uses PostgreSQL by default. Configure these environment variables
before starting it; no database password is committed:

```powershell
$env:DB_URL = "jdbc:postgresql://localhost:5432/evfleetdb"
$env:DB_USERNAME = "postgres"
$env:DB_PASSWORD = "<local-password>"
Set-Location backend
.\mvnw.cmd spring-boot:run
```

All user-owned endpoints currently use `X-User-Sub` as the authenticated
Cognito-subject boundary. This keeps ownership and authorization explicit for
local development; production deployment must replace this boundary with
Spring Security Cognito JWT validation.

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

Example local profile setup:

```powershell
curl.exe -X POST http://localhost:8080/api/users/me `
  -H "Content-Type: application/json" -H "X-User-Sub: demo-user" `
  -d '{\"fullName\":\"Demo User\",\"email\":\"demo@example.com\"}'
curl.exe http://localhost:8080/api/vehicles -H "X-User-Sub: demo-user"
```
