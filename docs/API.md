# API Reference — EV Fleet Intelligence

Base path: `/api`. Base URL in examples: `https://<api-host>` (the deployed backend; `http://localhost:8080` locally).

This reference is derived directly from the controllers, DTOs, entities and `SecurityConfig` in `backend/`. Endpoints that do not exist are **not** listed; the few that are partially implemented are marked **[NOT IMPLEMENTED]**.

---

## Authentication

- Spring Security is stateless and validates **Cognito access tokens**.
- Header: `Authorization: Bearer <cognito-access-token>`.
- The principal is the token's `sub` claim. Every ownership decision uses `users.cognito_sub`; no endpoint accepts a user id from the client.
- ID tokens are rejected (`token_use` must be `access`).
- `X-User-Sub` is not accepted.
- When `COGNITO_ENABLED=false` the server denies **all** `/api/**` requests except CORS preflight and `/actuator/health`.

**Who may call what**

| Marker | Meaning |
|---|---|
| *public* | No token required |
| *authenticated* | Any valid access token |
| *owner* | The authenticated user must own the resource (`users.id` = `owner_user_id` / `seeker_user_id`) |
| *role* | The profile's `role` must match exactly |

Profile roles: `VEHICLE_OWNER`, `CHARGER_PROVIDER`. A role is set once, when the profile is created (or while it is still `NULL`), and cannot be changed afterwards (`409`).

### Error body

All handled errors use one shape (`ApiExceptionHandler`):

```json
{
  "timestamp": "2026-10-29T12:34:56.789Z",
  "status": 409,
  "error": "Conflict",
  "message": "Station is already booked"
}
```

Validation errors add a `details` map of field → message:

```json
{
  "timestamp": "2026-10-29T12:34:56.789Z",
  "status": 400,
  "error": "Bad Request",
  "message": "Validation failed",
  "details": { "fullName": "must not be blank", "email": "must be a well-formed email address" }
}
```

Status codes used: `200`, `201`, `204`, `400`, `401`, `403`, `404`, `409`, `501`, `500`. `server.error.include-stacktrace=never`.

---

## 1. Authentication and identity

### GET /api/auth/me

Returns the validated token's claims plus the local profile when it exists.

- **Auth**: authenticated
- **Response 200 (profile exists)**:

```json
{
  "sub": "8f14e45f-ea6b-4d5c-9c1f-2b5e7a0c1234",
  "username": "driver@example.com",
  "email": "driver@example.com",
  "tokenUse": "access",
  "clientId": "1a2b3c4d5e6f7g8h9i0j",
  "localId": 12,
  "fullName": "Asha Kapoor",
  "role": "VEHICLE_OWNER",
  "onboardingCompleted": true
}
```

- **Response 200 (no profile yet)**:

```json
{
  "sub": "8f14e45f-ea6b-4d5c-9c1f-2b5e7a0c1234",
  "tokenUse": "access",
  "profileCreated": false
}
```

`profileCreated: false` means "Cognito identity valid, no local row" — the client must `PUT /api/users/me` before calling role endpoints.

- **401** when the token is missing, expired, from another issuer, or an ID token.

```powershell
$token = "<cognito-access-token>"
Invoke-RestMethod https://<api-host>/api/auth/me -Headers @{ Authorization = "Bearer $token" }
```

---

## 2. Users and profiles

### POST /api/users/me — create profile

- **Auth**: authenticated · **Status**: `201`
- Creates the row for the token's `sub`. If a row already exists the call behaves like `PUT` (idempotent create-or-update), except that a **different** role returns `409`.

```json
{
  "fullName": "Asha Kapoor",
  "email": "asha@example.com",
  "phone": "+91 98765 43210",
  "role": "VEHICLE_OWNER"
}
```

| Field | Required | Rules |
|---|---|---|
| `fullName` | yes | `@NotBlank`, ≤ 120 |
| `email` | yes | `@Email`, ≤ 254, unique (`409` on duplicate) |
| `phone` | no | ≤ 30 |
| `role` | no | `VEHICLE_OWNER` or `CHARGER_PROVIDER`; immutable once set |

Response (`AppUser`; `cognitoSub` is never serialised):

```json
{
  "id": 12,
  "fullName": "Asha Kapoor",
  "email": "asha@example.com",
  "phone": "+91 98765 43210",
  "role": "VEHICLE_OWNER",
  "onboardingCompleted": false,
  "onboardingStep": null,
  "createdAt": "2026-10-29T10:00:00Z",
  "updatedAt": "2026-10-29T10:00:00Z"
}
```

Errors: `400` validation / invalid role, `401`, `409` role change or duplicate email.

### GET /api/users/me — read profile

- **Auth**: authenticated · **200** `AppUser` · **404** when the profile has not been created.

### PUT /api/users/me — update profile

- **Auth**: authenticated · **200** `AppUser`
- Same body/validation as `POST`. Sending a `role` different from the stored one → `409`.

### PUT /api/users/me/onboarding — role and completion

- **Auth**: authenticated · **200** `AppUser`

```json
{ "role": "CHARGER_PROVIDER", "onboardingCompleted": true, "onboardingStep": 1 }
```

| Field | Rules |
|---|---|
| `role` | optional; must be a valid role; must equal the stored role (`409`) |
| `onboardingCompleted` | optional; **`true` requires an assigned role and at least one vehicle (owner) or station (provider)** → otherwise `400` |
| `onboardingStep` | optional; must be ≥ 1 |

This is the authoritative "profile complete" flag the Flutter router reads (`GET /api/auth/me` → `onboardingCompleted`).

### GET /api/users/me/sessions — charging history

- **Auth**: authenticated · **200** list of `ChargingSession`
- Returns sessions of bookings where the caller is the **seeker** only (provider-side history is not implemented, see `PROJECT_AUDIT.md` DATA-07).

---

## 3. Vehicles

All routes require authentication. `POST` also requires `role = VEHICLE_OWNER` (otherwise `403`).

### POST /api/vehicles — `201`

```json
{
  "vehicleType": "CAR",
  "brand": "Tata",
  "model": "Nexon EV",
  "registrationNumber": "MH12AB1234",
  "batteryCapacityKwh": 40.5,
  "connectorType": "CCS2"
}
```

| Field | Required | Schema limit |
|---|---|---|
| `vehicleType` | yes (`@NotBlank`) | 20 |
| `brand` | no | 80 |
| `model` | yes (`@NotBlank`) | 80 |
| `registrationNumber` | no | 30 |
| `batteryCapacityKwh` | no | numeric(7,2) |
| `connectorType` | no | 40 — compared case-insensitively with the station's connector when booking |

Response: `{ "id": 4, "ownerUserId": 12, "vehicleType": "CAR", "brand": "Tata", "model": "Nexon EV", "registrationNumber": "MH12AB1234", "batteryCapacityKwh": 40.50, "connectorType": "CCS2" }`

### GET /api/vehicles — `200` list

Owned vehicles only (`ownerUserId` = caller).

### GET /api/vehicles/{id} — `200` · **403** other owner · **404** missing

### PUT /api/vehicles/{id} — `200`

Same body as `POST`; `vehicleType` and `model` stay required.

### DELETE /api/vehicles/{id} — `204`

Hard delete. A vehicle referenced by an existing booking is still deletable (the booking keeps the id); delete is physical, not soft.

```powershell
Invoke-RestMethod -Method Post https://<api-host>/api/vehicles `
  -Headers @{ Authorization = "Bearer $token" } -ContentType "application/json" `
  -Body '{"vehicleType":"CAR","brand":"Tata","model":"Nexon EV","connectorType":"CCS2"}'
```

---

## 4. Charging stations

### POST /api/stations — `201` — *role* `CHARGER_PROVIDER`

```json
{
  "stationName": "Green Park Home Charger",
  "providerType": "HOUSEHOLD",
  "accessType": "PUBLIC",
  "address": "12 Palm Grove, Pune 411001",
  "latitude": 18.520430,
  "longitude": 73.856743,
  "connectorType": "Type 2",
  "powerKw": 7.4,
  "pricePerKwh": 14.50
}
```

| Field | Required | Rules |
|---|---|---|
| `stationName` | yes | ≤ 140 |
| `providerType` | yes | ≤ 20 (`HOUSEHOLD`, `PUBLIC`, … free text) |
| `accessType` | yes | ≤ 20 (`PUBLIC`, `PRIVATE`) |
| `address` | yes | free text |
| `latitude` | yes | −90 … 90, numeric(9,6) |
| `longitude` | yes | −180 … 180, numeric(9,6) |
| `connectorType` | yes | ≤ 40 |
| `powerKw` | yes | > 0 |
| `pricePerKwh` | no | ≥ 0 |

`ownerUserId` and `active` are assigned by the server and ignored if supplied. Response is the created `ChargingStation`.

### GET /api/stations — *public* — `200`

Active stations only, newest first as stored. No pagination.

### GET /api/stations/nearby — *public* — `200`

| Query | Required | Rules |
|---|---|---|
| `latitude` | yes | −90 … 90 |
| `longitude` | yes | −180 … 180 |
| `radiusKm` | yes | > 0 and ≤ **50** |

Returns active stations within the radius, nearest first. Distance is not included in the payload; the client computes it from the returned coordinates. Invalid input or `radiusKm > 50` → `400 {"message":"Invalid coordinates or radius"}`. Filtering/sorting currently happens in memory over `findByActiveTrue()` (see `PROJECT_AUDIT.md` DATA-04).

### GET /api/stations/mine — *authenticated* — `200`

Stations owned by the caller, **including inactive** ones.

### GET /api/stations/{id} — *public* — `200` · **404**

Only **active** stations are returned publicly. An owner following a link to their own hidden station also gets `404` (DATA-05).

### PUT /api/stations/{id} — *owner* — `200`

Same body as `POST`. `ownerUserId` and the current `active` flag are preserved.

### PUT /api/stations/{id}/status — *owner* — `200`

```json
{ "active": false }
```

Hides (`false`) or publishes (`true`) the listing. Deactivated stations disappear from `GET /api/stations` and `nearby`.

### DELETE /api/stations/{id} — *owner* — `204`

Soft delete: sets `active = false`. The row, its availability and bookings are retained.

```powershell
Invoke-RestMethod https://<api-host>/api/stations/nearby `
  -Body @{ latitude = 18.5204; longitude = 73.8567; radiusKm = 5 } -Method Get
```

---

## 5. Availability windows

### GET /api/stations/{id}/availability — *public* — `200`

```json
[ { "id": 30, "stationId": 7, "startTime": "2026-11-01T06:00:00Z", "endTime": "2026-11-01T10:00:00Z", "status": "AVAILABLE" } ]
```

### POST /api/stations/{id}/availability — *owner* — `201`

```json
{ "startTime": "2026-11-01T06:00:00Z", "endTime": "2026-11-01T10:00:00Z", "status": "AVAILABLE" }
```

`endTime` must be after `startTime` (`400`). Overlapping an existing window of the same station → `409 {"message":"Availability overlaps"}`.

### PUT /api/stations/{id}/availability/{windowId} — *owner* — `200`

Same body. Also rejects overlap with the provider's **other** windows (`409`) and returns `404` when the window belongs to another station.

### DELETE /api/stations/{id}/availability/{windowId} — *owner* — `204`

Booking requires a window that fully contains the requested interval.

---

## 6. Bookings

Statuses: `PENDING` → `CONFIRMED` | `REJECTED`, and `PENDING`/`CONFIRMED` → `CANCELLED`.

### POST /api/bookings — *authenticated* — `201`

```json
{
  "vehicleId": 4,
  "stationId": 7,
  "startTime": "2026-11-01T07:00:00Z",
  "endTime": "2026-11-01T09:00:00Z"
}
```

Server-side rules (all enforced in `PlatformService.createBooking`):

1. `vehicleId` and `stationId` are required → `400`.
2. The vehicle must belong to the caller → `403` / `404`.
3. The station must exist and be active → `404`.
4. `endTime` after `startTime` → `400`.
5. Connector compatibility (case-insensitive; skipped when the vehicle has none) → `409 "Vehicle connector is incompatible with station"`.
6. A published availability window must contain the interval → `409 "Requested time is not available"`.
7. No `PENDING`/`CONFIRMED` overlap on the station → `409 "Station is already booked"`.
8. `seekerUserId` and `status = "PENDING"` are forced by the server.
9. `estimatedCost = pricePerKwh × durationHours`, rounded to 2 dp (`null` when the station has no price).

Response:

```json
{
  "id": 51,
  "seekerUserId": 12,
  "vehicleId": 4,
  "stationId": 7,
  "startTime": "2026-11-01T07:00:00Z",
  "endTime": "2026-11-01T09:00:00Z",
  "status": "PENDING",
  "estimatedCost": 29.00
}
```

### GET /api/bookings — *authenticated* — `200`

Bookings where the caller is the **seeker**. Providers use `GET /api/stations/{id}/bookings`.

### GET /api/bookings/{id} — *authenticated* — `200` · **403** · **404**

Readable by the seeker **or** the owner of the station.

### PUT /api/bookings/{id}/cancel — *seeker only* — `200`

Allowed when `status` is `PENDING` or `CONFIRMED` → `CANCELLED`. Any other status → `409`. A provider calling this on someone else's booking → `403`.

### PUT /api/bookings/{id}/confirm — *station owner only* — `200`

`PENDING` → `CONFIRMED`. The seeker **cannot** confirm their own booking (`403`). Non-pending → `409`.

### PUT /api/bookings/{id}/reject — *station owner only* — `200`

`PENDING` → `REJECTED`. Same authorization as confirm.

### GET /api/stations/{id}/bookings — *owner* — `200`

All bookings for that station, in storage order.

```powershell
Invoke-RestMethod -Method Put https://<api-host>/api/bookings/51/confirm `
  -Headers @{ Authorization = "Bearer $providerToken" }
```

---

## 7. Charging sessions

### POST /api/bookings/{bookingId}/sessions — *authenticated* — `201`

Starts a session for a `CONFIRMED` booking (seeker or station owner). `409` when the booking is not confirmed or a session already exists for it. Sets `status = "IN_PROGRESS"` and `actualStartTime = now`.

### GET /api/sessions/{id} — *authenticated* — `200`

Readable by the booking's seeker or the station owner.

### PUT /api/sessions/{id}/complete — `200`

```json
{ "energyConsumedKwh": 18.4, "finalCost": 266.80 }
```

Requires `IN_PROGRESS` (`409` otherwise), `energyConsumedKwh >= 0` (`400` otherwise). Sets `actualEndTime = now` and `status = "COMPLETED"`.

```json
{
  "id": 9,
  "bookingId": 51,
  "actualStartTime": "2026-11-01T07:02:11Z",
  "actualEndTime": "2026-11-01T08:58:40Z",
  "energyConsumedKwh": 18.40,
  "finalCost": 266.80,
  "status": "COMPLETED"
}
```

---

## 8. Station images

The database records image metadata; **binary upload to S3 is not implemented**. No AWS credentials or bucket are configured anywhere in the application.

| Method | Path | Auth | Result |
|---|---|---|---|
| GET | `/api/stations/{stationId}/images` | authenticated | `200` list of stored rows |
| POST | `/api/stations/{stationId}/images/upload-url` | owner | **[NOT IMPLEMENTED]** `501` — previously returned a fabricated local URL and object key |
| POST | `/api/stations/{stationId}/images` | owner | `201` with `{ "s3ObjectKey": "..." }`; `400` when blank |
| DELETE | `/api/stations/{stationId}/images/{imageId}` | owner | `204` |

Because `POST /images` accepts any key without verifying the object exists, a row can reference a missing S3 object. Intended contract for a future implementation:

1. `POST /upload-url` returns `{ "uploadUrl": "<presigned PUT>", "s3ObjectKey": "<key>", "expiresIn": 300 }`.
2. The client `PUT`s the bytes directly to `uploadUrl`.
3. The client `POST /images` with the returned key to persist metadata.

---

## 9. Health and operations

### GET /actuator/health — *public* — `200`

```json
{ "status": "UP" }
```

Only `health` is exposed (`management.endpoints.web.exposure.include=health`). Details require authorisation.

---

## 10. Screen-to-endpoint mapping (Flutter)

| Screen / action | Call |
|---|---|
| Sign in (Cognito) | Amplify directly; then `GET /api/auth/me` |
| Create profile on first sign-in | `PUT /api/users/me` |
| Complete onboarding | `POST /api/vehicles` or `POST /api/stations`, then `PUT /api/users/me/onboarding` |
| Explore stations | `GET /api/stations/nearby` (device location + radius) |
| Station details | `GET /api/stations/{id}`, `GET /api/stations/{id}/availability` |
| Book a slot | `POST /api/bookings` |
| My bookings | `GET /api/bookings`, `PUT /api/bookings/{id}/cancel` |
| My vehicles | `GET/POST/PUT/DELETE /api/vehicles` |
| Provider dashboard stations | `GET /api/stations/mine` |
| Provider availability | `POST/PUT/DELETE /api/stations/{id}/availability` |
| Provider booking decisions | `GET /api/stations/{id}/bookings`, `PUT /api/bookings/{id}/confirm|reject` |
| Profile | `GET/PUT /api/users/me` |

A narrated walkthrough of the same mapping lives in `frontend/docs/API_INTEGRATION.md`.
