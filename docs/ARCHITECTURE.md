# Architecture — EV Fleet Intelligence

Last reviewed: 2026-10-29. Describes the system **as implemented**, not as planned.

---

## 1. System overview

```
┌────────────────────────┐        HTTPS + Cognito access token        ┌──────────────────────────┐
│  Flutter app           │ ─────────────────────────────────────────▶ │  Spring Boot API         │
│  frontend/             │                                            │  backend/  (:8080)       │
│                        │ ◀───────────────────────────────────────── │                          │
│  GoRouter + Riverpod   │                JSON / REST                 │  Security → Controller   │
│  Amplify Auth (Cognito)│                                            │   → Service → Repository │
└──────────┬─────────────┘                                            └────────────┬─────────────┘
           │                                                                       │ JDBC (TLS)
           │ SRP sign-up / sign-in / confirm                                       │
           ▼                                                                       ▼
┌────────────────────────┐                                            ┌──────────────────────────┐
│ Amazon Cognito         │  JWKS + issuer  ◀──── JWT validation ───── │  Amazon RDS PostgreSQL   │
│ User Pool (email code) │                                            │  Flyway-managed schema   │
└────────────────────────┘                                            └──────────────────────────┘
                                                                                 ▲
                                                          Amazon S3 (NOT wired) ─┘
```

- **Client**: Flutter 3.47 / Dart, single active app (`frontend/lib/app/app.dart`), Riverpod providers, GoRouter, Material 3, `geolocator`, `dio`, `flutter_secure_storage`.
- **API**: Spring Boot 4.1.1 on Java 21, stateless, `spring-boot-starter-oauth2-resource-server`.
- **Identity**: Cognito User Pool with email verification; the API never stores credentials.
- **Data**: PostgreSQL on RDS; `V1__create_initial_schema.sql` is the only migration.
- **Hosting**: EC2 + systemd behind an ALB (see `AWS_DEPLOYMENT_GUIDE.md`).

---

## 2. Request lifecycle

1. The Flutter API client (`frontend/lib/core/network/backend_api_service.dart`) builds the request on a shared `Dio` instance.
2. `api_interceptors.dart` attaches `Authorization: Bearer <access token>` from secure storage.
3. `SecurityConfig` matches the path:
   - CORS preflight and `/actuator/health`, `/error` → open.
   - `GET /api/stations`, `/api/stations/nearby`, `/api/stations/{id}`, `/api/stations/{id}/availability` → public.
   - `GET /api/stations/mine` → **authenticated** (explicitly, before the public `{id}` pattern).
   - everything else → authenticated.
4. The resource server decodes the JWT against Cognito's JWKS, validating signature, issuer, expiry and `token_use = access`. `sub` becomes the principal name.
5. The controller extracts the subject with `CurrentUser.subject(authentication)` and passes it to a service. **No endpoint trusts a client-supplied user id.**
6. `PlatformService` loads the local `AppUser` by `cognito_sub`, applies ownership/role checks, and persists through a Spring Data repository.
7. Failures become `ResponseStatusException` → normalised JSON by `ApiExceptionHandler`. JPA constraint violations become `409`.
8. The client maps status codes to user-facing strings in `error_handler.dart` (401 clears the session and returns to `/login`).

---

## 3. Authentication and authorization

### Cognito ↔ database mapping

| Cognito | Database |
|---|---|
| `sub` (stable UUID) | `users.cognito_sub` (unique, never serialised) |
| `email` | `users.email` (unique) |
| `name` attribute | `users.full_name` at profile creation |

A verified Cognito identity does **not** create a profile automatically. `GET /api/auth/me` returns `profileCreated: false` until the client calls `PUT /api/users/me`. This is the boundary between "authenticated" and "usable".

### Roles

`VEHICLE_OWNER` or `CHARGER_PROVIDER`, stored in `users.role`:

- Assigned when the profile is created (or while it is still `NULL`).
- Changing it later → `409`.
- Enforced in `PlatformService.requireRole`: no role → `403`; wrong role → `403`. A profile without a role can create **neither** vehicles nor stations.

### Ownership

| Resource | Rule |
|---|---|
| `vehicles` | `owner_user_id` = caller's `users.id` |
| `charging_stations` | `owner_user_id` = caller's `users.id` (write, status, availability, images, station bookings) |
| `bookings` | seeker **or** station owner may read; only the seeker may cancel; only the station owner may confirm/reject |
| `charging_sessions` | reachable through a booking the caller may read |
| `station_images` | station owner may mutate; reads require authentication |

---

## 4. Onboarding state machine

`onboardingCompleted` lives in the database and is the only source of truth; the client caches it in `SharedPreferences` purely to avoid a blank screen on launch and overwrites it from `GET /api/auth/me` whenever it can.

```
                    ┌──────────┐
   no session ────▶ │ /login   │ ◀──── sign-out / 401 / expired token
                    └────┬─────┘
                         │ Cognito sign-in + GET /api/auth/me
          ┌──────────────┴───────────────┐
          │ role == null                 │ role set
          ▼                              ▼
    /login (role is set         onboardingCompleted?
     with the profile)            │true        │false
                                  ▼            ▼
                              /home or      /account-setup
                              /provider     (POST vehicle|station,
                                             then PUT onboarding)
```

- `/register` → Cognito `signUp` → `/verify-email` → confirm code + auto sign-in → `/account-setup` (or `/home` if already complete).
- The guard is a numbered cascade in `_createRouter().redirect`: no-session → role-missing → setup-incomplete → completed-users-cannot-see-auth-screens → role dashboard separation. Each branch returns a different route or `null`, so self-redirects (loops) are impossible.
- `PUT /api/users/me/onboarding` now refuses `onboardingCompleted: true` unless a role is assigned and at least one vehicle/station exists.

---

## 5. Data model

```
users (id)
 ├─1:N─ vehicles (owner_user_id, FK by value)
 ├─1:N─ charging_stations (owner_user_id)
 └─1:N─ bookings (seeker_user_id)

charging_stations (id)
 ├─1:N─ charger_availability (station_id)
 ├─1:N─ bookings (station_id)
 └─1:N─ station_images (station_id)

vehicles (id) ─1:N─ bookings (vehicle_id)
bookings (id) ─1:1─ charging_sessions (booking_id, UNIQUE)
```

All relationships are **by id value, not JPA associations** — there are no `@ManyToOne` edges, so there is no cascade behaviour and no lazy-loading graph. Every join is an explicit repository query.

Constraints and indexes actually present:

| Table | Constraint / index |
|---|---|
| `users` | `uk_users_sub` (unique), `uk_users_email` (unique) |
| `vehicles` | `idx_vehicles_owner` |
| `charging_stations` | `idx_stations_owner`, latitude/longitude numeric(9,6) |
| `bookings` | `idx_bookings_station_time (station_id, start_time, end_time)` |
| `charging_sessions` | `uk_session_booking` (one session per booking) |
| `station_images` | `uk_image_key` (unique object key) |
| `charger_availability` | none — overlap prevented in the service layer |

There are deliberately **no foreign-key constraints** in V1; referential integrity is enforced by the service layer and by ownership checks. Deleting a vehicle therefore leaves its bookings in place.

---

## 6. Primary flows

### 6.1 Registration

```
App                     Cognito                     API
 │ signUp(email,pw,name)  │                          │
 ├───────────────────────▶│ sends code               │
 │ confirmSignUp(code)    │                          │
 ├───────────────────────▶│ verified                 │
 │ signIn (password held in memory only)             │
 ├───────────────────────▶│ access token             │
 │ GET /api/auth/me ─────────────────────────────────▶│ profileCreated:false
 │ PUT /api/users/me {role} ─────────────────────────▶│ row created
 │ ── redirect /account-setup ──                     │
 │ POST /api/vehicles | /api/stations                │
 │ PUT /api/users/me/onboarding {completed:true} ────▶│ precondition checked
 │ GET /api/auth/me ─────────────────────────────────▶│ onboardingCompleted:true
 │ ── redirect /home | /provider ──                  │
```

The registration password is never persisted; if the process dies before verification, the user verifies and signs in normally.

### 6.2 Login / session restore

`Amplify.Auth.fetchAuthSession()` restores the Cognito session; the access token is copied into secure storage. The profile is then fetched. A backend outage at startup keeps the last known local state instead of signing the user out; a `401` from any call clears the session and routes to `/login`.

### 6.3 Station discovery

The device location (`geolocator`, runtime permission) plus the selected radius (1–50 km) go to `GET /api/stations/nearby`. The **server** filters by haversine distance and returns active stations nearest-first; the client does not download the catalogue and filter locally. Distances shown in the UI are computed client-side from returned coordinates.

### 6.4 Booking and provider decision

```
seeker: POST /api/bookings ──▶ validates vehicle ownership, station active,
                              connector, availability window, overlap
                              → status PENDING (+ estimatedCost)
provider: PUT /api/bookings/{id}/confirm ──▶ station-owner check → CONFIRMED
seeker:   PUT /api/bookings/{id}/cancel  ──▶ seeker check → CANCELLED
```

Availability and overlap checks are advisory within a single transaction (no `SELECT … FOR UPDATE`), so two simultaneous requests can both pass the check. The 50 ms-scale window is acceptable for the MVP; a unique partial index on `(station_id, tstzrange(start_time, end_time))` excluding cancelled rows would make it airtight.

---

## 7. AWS topology

| Layer | Service | Notes |
|---|---|---|
| Mobile clients | — | `API_BASE_URL` + Cognito pool/client ids injected with `--dart-define` |
| Auth | Cognito User Pool | Public app client (no secret), email verification code |
| Compute | EC2 + systemd | `spring-boot` jar, graceful shutdown, `/actuator/health` |
| Edge | ALB (+ ACM) | HTTPS termination; **required before release** (CFG-04) |
| Data | RDS PostgreSQL | Private subnets; 5432 only from the EC2 security group |
| Objects | S3 | **Not configured** — image uploads return `501` |
| Logs | journald → CloudWatch (optional) | No secrets are logged |

Required environment variables are listed in `backend/README.md`. `DB_URL` is now actually read by `application.properties`; `SPRING_DATASOURCE_URL` still overrides it.

---

## 8. Failure modes and recovery

| Failure | Behaviour | Recovery |
|---|---|---|
| Cognito unreachable at startup | With `COGNITO_ENABLED=true`, issuer discovery (`JwtDecoders.fromIssuerLocation`) can fail the boot | Retry/restart; see CFG-05 for a resilient decoder |
| `COGNITO_ENABLED` unset in prod | Every `/api/**` request → `403`; health stays `UP` | Set the variable and restart |
| API unreachable from the app | Explicit error state; demo data is **never** substituted (`DEMO_MODE` is opt-in only) | Retry, check URL/CORS |
| Expired/revoked token | Any call → `401`; the client clears the session and shows `/login` | Sign in again |
| Profile missing after sign-in | `profileCreated:false`; sign-in creates it | Automatic |
| Role missing (legacy row) | Sign-in assigns the role once; write endpoints reject until then | Automatic on next sign-in, or backfill SQL |
| Onboarding half-done | `onboardingCompleted=false` keeps the user on `/account-setup` across restarts | Resume; retry recreates the vehicle/station (no idempotency key) |
| Slot taken between check and insert | Both requests can pass the overlap check | `409` path exists for sequential conflicts; add locking for concurrency |
| Flyway finds a non-empty schema | Now baselined (`baseline-on-migrate=true`) instead of failing | Confirm the schema matches V1 |
| Missing `DB_URL` | Connects to `localhost:5432` | Set the variable; health check catches it |
| S3 not configured | `501` from `upload-url` | Configure a bucket and presigned uploads (TASK-13) |

---

## 9. Security model summary

1. Cognito owns authentication; the API owns authorization.
2. JWT validation: signature, issuer, expiry, `token_use=access`. Missing: `client_id` allow-list (SEC-06).
3. Identity is always derived from `sub`; no endpoint accepts a user id.
4. Role checks are strict; no role means no write capability.
5. Ownership is checked per resource on every read/write.
6. CORS allows exactly one configured origin with credentials.
7. Secrets live only in the process environment; the client ships no secrets and no tokens in `.env`.
8. Release builds refuse a non-HTTPS API origin; debug builds allow the documented EC2 exception.
9. Passwords and tokens are never logged; `server.error.include-message=never`.

---

## 10. Known architectural gaps

- No pagination anywhere; list endpoints return full collections.
- No provider-wide booking or session view (per-station fan-out).
- No image storage; metadata only.
- No notifications, chat or provider contact channel.
- Nearby search is in-memory over active stations (no PostGIS/bbox index).
- No idempotency keys for onboarding writes, so a retry after a partial failure can duplicate a vehicle/station.
- Frontend route and widget code is concentrated in one 4.9k-line file.

Each gap is tracked with a severity and status in `PROJECT_AUDIT.md`.
