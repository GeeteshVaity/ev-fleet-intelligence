# API Integration Sheet — EV Fleet Intelligence (Flutter client)

Every endpoint below was read from the Spring Boot controllers in `backend/src/main/java/com/evfleet/backend/controller/`.
Nothing here is proposed or invented. Endpoints the client does **not** call yet are marked as such.

- **Base URL:** configured with `API_BASE_URL` (default `http://13.204.143.82:8080`). No trailing slash.
- **Auth scheme:** `Authorization: Bearer <Cognito ACCESS token>`. ID tokens are rejected by the backend (`token_use` must be `access`).
- **Content type:** `application/json` for all bodies.
- **Timestamps:** ISO-8601 UTC (`2026-10-29T09:30:00Z`), sent by the client with `.toUtc().toIso8601String()`.
- **Public (no token):** `GET /api/stations`, `GET /api/stations/nearby`, `GET /api/stations/{id}`, `GET /api/stations/{id}/availability`, `OPTIONS /**`, `/actuator/health`.
- **Everything else:** requires a valid access token (`401` otherwise).

---

## 1. Authentication and profile

| Method | Path | Auth | Client usage |
| --- | --- | --- | --- |
| GET | `/api/auth/me` | Bearer | Session restore + role/onboarding source of truth |
| POST | `/api/users/me` | Bearer | Create the local profile (201) |
| PUT | `/api/users/me` | Bearer | Create-or-update the local profile |
| GET | `/api/users/me` | Bearer | Profile screen; `404` when no profile exists |
| PUT | `/api/users/me/onboarding` | Bearer | Persist role selection and onboarding progress |

### GET /api/auth/me

Response when the profile exists:

```json
{
  "sub": "8f14e45f-ceea-467f-a8e9-3b1c4c9d1d0a",
  "username": "driver@example.com",
  "email": "driver@example.com",
  "tokenUse": "access",
  "clientId": "cu99248mdofvm2p56lccnit0h",
  "localId": 12,
  "fullName": "Asha Rao",
  "role": "VEHICLE_OWNER",
  "onboardingCompleted": true
}
```

Response when no local profile exists yet (token is still valid):

```json
{ "sub": "8f14e45f-...", "username": "driver@example.com", "tokenUse": "access", "profileCreated": false }
```

Client behaviour: `profileCreated: false` → the app creates the profile with `PUT /api/users/me` and then re-reads `/api/auth/me`.
The `role` and `onboardingCompleted` from this response **override** any cached value in `SharedPreferences`.

### PUT /api/users/me

```json
{ "fullName": "Asha Rao", "email": "asha@example.com", "phone": "+91 90000 00000", "role": "VEHICLE_OWNER" }
```

Validation: `fullName` 1–120 chars (required), `email` valid and ≤254 (required), `phone` ≤30 (optional),
`role` ≤30 (optional). `400` on validation failure, `409` on duplicate e-mail/`cognito_sub`.

### PUT /api/users/me/onboarding

```json
{ "role": "CHARGER_PROVIDER", "onboardingCompleted": true, "onboardingStep": 1 }
```

Accepted roles are only `VEHICLE_OWNER` and `CHARGER_PROVIDER`; anything else is `400`.

---

## 2. Stations

| Method | Path | Auth | Client usage |
| --- | --- | --- | --- |
| GET | `/api/stations` | public | Catalogue when no device location is available |
| GET | `/api/stations/nearby?latitude=&longitude=&radiusKm=` | public | Explore with device location (server-side radius search) |
| GET | `/api/stations/mine` | Bearer | Provider "My chargers" |
| GET | `/api/stations/{id}` | public | Station details (inactive → `404`) |
| POST | `/api/stations` | Bearer, `CHARGER_PROVIDER` | Provider onboarding + "list charger" |
| PUT | `/api/stations/{id}` | Bearer, owner | **Not called by the client yet** |
| PUT | `/api/stations/{id}/status` | Bearer, owner | Publish/hide toggle (`{"active": false}`) |
| DELETE | `/api/stations/{id}` | Bearer, owner | **Not called by the client yet** (soft delete = `active=false`) |
| GET | `/api/stations/{id}/availability` | public | Availability windows |
| POST | `/api/stations/{id}/availability` | Bearer, owner | Provider publishes a window |
| PUT | `/api/stations/{id}/availability/{windowId}` | Bearer, owner | **Not called by the client yet** |
| DELETE | `/api/stations/{id}/availability/{windowId}` | Bearer, owner | Provider removes a window |
| GET | `/api/stations/{id}/bookings` | Bearer, owner | Provider "Booking requests" |

### GET /api/stations/nearby

Query: `latitude` (−90…90), `longitude` (−180…180), `radiusKm` (> 0).

Behaviour verified in `PlatformService.nearby`:

- validates the coordinates and a positive radius → `400 "Invalid coordinates or radius"` otherwise;
- only active stations (`findByActiveTrue`);
- great-circle distance in **kilometres** (haversine, R = 6371);
- returns stations with `distance <= radiusKm`, **sorted ascending by distance**.

The response is the station entity array; the distance itself is not included, so the client recomputes
it for the label with the same haversine formula. The client caps `radiusKm` at 50 and offers 1 / 5 / 10 / 25 / 50 km.

```json
[
  {
    "id": 4,
    "ownerUserId": 12,
    "stationName": "Green Park Charger",
    "providerType": "HOUSEHOLD",
    "accessType": "PRIVATE",
    "address": "12 Green Park, Pune",
    "latitude": 18.520430,
    "longitude": 73.856743,
    "connectorType": "TYPE2",
    "powerKw": 7.40,
    "pricePerKwh": 14.50,
    "active": true
  }
]
```

### POST /api/stations

```json
{
  "stationName": "Green Park Charger",
  "providerType": "HOUSEHOLD",
  "accessType": "PRIVATE",
  "address": "12 Green Park, Pune",
  "latitude": 18.520430,
  "longitude": 73.856743,
  "connectorType": "TYPE2",
  "powerKw": 7.4,
  "pricePerKwh": 14.5
}
```

`201` with the created entity. `400` for missing required fields, out-of-range coordinates or non-positive `powerKw`.
`403` when the caller's role is not `CHARGER_PROVIDER`. `ownerUserId` is always overwritten by the backend from the token.

### POST /api/stations/{id}/availability

```json
{ "startTime": "2026-10-30T04:00:00Z", "endTime": "2026-10-30T08:00:00Z", "status": "AVAILABLE" }
```

`201` on success. `400` when `endTime` is not after `startTime`. `409 "Availability overlaps"` when the window
overlaps an existing one. `403` when the station is not owned by the caller.

---

## 3. Vehicles

| Method | Path | Auth | Client usage |
| --- | --- | --- | --- |
| GET | `/api/vehicles` | Bearer | "My vehicles" |
| POST | `/api/vehicles` | Bearer, `VEHICLE_OWNER` | Add vehicle |
| GET | `/api/vehicles/{id}` | Bearer, owner | **Not called by the client yet** |
| PUT | `/api/vehicles/{id}` | Bearer, owner | **Not called by the client yet** (edit form is UI-only) |
| DELETE | `/api/vehicles/{id}` | Bearer, owner | Delete vehicle |

```json
{ "vehicleType": "CAR", "brand": "Tata", "model": "Nexon EV", "registrationNumber": "MH12AB1234",
  "batteryCapacityKwh": 40.5, "connectorType": "TYPE2" }
```

Validation: `vehicleType` and `model` required; `batteryCapacityKwh` must be positive; `ownerUserId` comes from the token.

---

## 4. Bookings

| Method | Path | Auth | Client usage |
| --- | --- | --- | --- |
| POST | `/api/bookings` | Bearer | "Book charging slot" |
| GET | `/api/bookings` | Bearer | "My bookings" (requests where the caller is the seeker) |
| GET | `/api/bookings/{id}` | Bearer, seeker or station owner | **Not called by the client yet** |
| PUT | `/api/bookings/{id}/cancel` | Bearer, seeker or station owner | Cancel action |
| PUT | `/api/bookings/{id}/confirm` | Bearer, station owner | Provider confirms a request |
| PUT | `/api/bookings/{id}/reject` | Bearer, station owner | Provider rejects a request |

### POST /api/bookings

```json
{ "vehicleId": 7, "stationId": 4, "startTime": "2026-10-30T04:00:00Z", "endTime": "2026-10-30T06:00:00Z" }
```

Server checks, in order (`PlatformService.createBooking`):

1. the vehicle belongs to the caller (`403`/`404` otherwise);
2. `endTime > startTime` (`400`);
3. connector compatibility with the station, only when the vehicle has a connector set → `409 "Vehicle connector is incompatible with station"`;
4. an `AVAILABLE` window covers the requested range → `409 "Requested time is not available"`;
5. no `PENDING`/`CONFIRMED` booking overlaps → `409 "Station is already booked"`.

The persisted status is always `PENDING`; the client never assumes `CONFIRMED`.

### PUT /api/bookings/{id}/confirm | /reject

No body. Response is the updated entity with `"status": "CONFIRMED"` or `"REJECTED"`.
`409 "Booking is not pending"` when the request was already decided — the client re-reads the list and shows
the server message instead of flipping the badge locally.

### Status vocabulary (verified)

`PENDING`, `CONFIRMED`, `REJECTED`, `CANCELLED`. There is no `COMPLETED` booking status; completion lives on
`charging_sessions` (`IN_PROGRESS` → `COMPLETED`), which the client does not yet drive.

---

## 5. Charging sessions (backend only)

`POST /api/bookings/{bookingId}/sessions`, `GET /api/sessions/{id}`, `PUT /api/sessions/{id}/complete`,
`GET /api/users/me/sessions` exist and require a `CONFIRMED` booking. **The client does not call them yet**;
charging history in the UI is an explicit "not connected in this build" state.

---

## 6. Station images (backend partially implemented)

| Method | Path | Status |
| --- | --- | --- |
| GET | `/api/stations/{stationId}/images` | Works, but requires a bearer token (not in the public matcher list) |
| POST | `/api/stations/{stationId}/images/upload-url` | **Stub** — returns `{"uploadUrl": "/api/stations/{id}/images", "s3ObjectKey": "...", "note": "Configure S3 presigned URLs before production"}`. It does not sign a real S3 URL. |
| POST | `/api/stations/{stationId}/images` | Persists `{ "s3ObjectKey": "..." }` metadata only |
| DELETE | `/api/stations/{stationId}/images/{imageId}` | Works for the owner |

No S3 bucket/region is configured in `application*.properties`, and the client has no image upload UI.
**Image upload is not implemented end-to-end.**

---

## 7. Screen → endpoint mapping

| Screen (active UI) | Requests |
| --- | --- |
| Startup / session restore | `GET /api/auth/me`, `PUT /api/users/me` (only when `profileCreated == false`) |
| Sign in / Sign up / Verify e-mail | Cognito only (no REST call) |
| Role selection | `PUT /api/users/me` (role), `PUT /api/users/me/onboarding` |
| Vehicle onboarding | `PUT /api/users/me` → `POST /api/vehicles` → `PUT /api/users/me/onboarding` |
| Provider onboarding | `PUT /api/users/me` → `POST /api/stations` → `PUT /api/users/me/onboarding` |
| Home (vehicle user) | `GET /api/stations` or `/nearby`, `GET /api/bookings`, `GET /api/users/me` |
| Explore | `GET /api/stations/nearby` (with location) or `GET /api/stations`, `GET /api/stations/{id}/availability` per station |
| Station details | `GET /api/stations/{id}/availability`, `GET /api/vehicles` |
| Booking flow | `POST /api/bookings` |
| My bookings | `GET /api/bookings`, `PUT /api/bookings/{id}/cancel` |
| My vehicles | `GET /api/vehicles`, `POST /api/vehicles`, `DELETE /api/vehicles/{id}` |
| Profile | `GET /api/users/me`, `PUT /api/users/me` |
| Provider dashboard | `GET /api/stations/mine`, `GET /api/stations/{id}/bookings` |
| My chargers | `GET /api/stations/mine`, `PUT /api/stations/{id}/status`, availability POST/DELETE |
| Booking requests | `GET /api/stations/{id}/bookings`, `PUT /api/bookings/{id}/confirm|reject` |

---

## 8. Error handling

One mapper (`lib/core/errors/error_handler.dart`) converts `DioException` into a user-safe `AppException`:

| Server response | User-facing result |
| --- | --- |
| `400` | Validation message from the server when it is safe, otherwise a generic one |
| `401` | Session ended: local session cleared, user returned to sign-in (`SessionEvents.onUnauthorized`) |
| `403` | "You do not have permission to do that." |
| `404` | "Not found." |
| `409` | The server's conflict message (e.g. slot taken / already booked) + list refresh |
| `5xx` | "The server had a problem. Try again." |
| Timeout / no network | "Could not reach the server." with a Retry action |

No error path falls back to sample data, and no response body is rendered raw (class names and stack traces are stripped).

---

## 9. Known gaps in the contract

1. **No `COMPLETED` booking state** — the UI groups bookings by the four statuses that exist.
2. **`GET /api/bookings` only returns bookings where the caller is the seeker**, so the provider screens aggregate
   per station via `GET /api/stations/{id}/bookings`.
3. **Station edit/delete** endpoints exist but the UI does not call them yet.
4. **S3 presigned upload** is a stub (see §6).
5. **No availability "status" editing UI** beyond publish/delete; `PUT .../availability/{windowId}` is unused.
6. **No `GET /api/stations/{id}` support for inactive stations** — deactivated listings return `404` to their own owner,
   so the provider UI reads them from `GET /api/stations/mine` instead.
7. **Role enforcement is conditional on a non-null role** (`PlatformService.requireRole`): a profile with `role == null`
   is allowed to create both vehicles and stations. Assigning a role at onboarding closes this for new accounts,
   but older or manually created rows must be backfilled.
