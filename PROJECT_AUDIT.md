# Project Audit — EV Fleet Intelligence

Audit date: 2026-10-29
Repository: `ev-fleet-intelligence` (branch `main`)
Scope: `frontend/` (Flutter), `backend/` (Spring Boot), PostgreSQL schema, AWS/Cognito configuration, documentation.

Every finding below was read out of the source in this repository. Nothing is inferred from the README alone, and no secret values are reproduced here.

---

## 0. Baseline (measured before any change)

| Check | Command | Result |
|---|---|---|
| Backend compile + tests | `mvn -B test` (in `backend/`) | **27 tests, 0 failures** (`PlatformServiceTest` 12, `PlatformControllerTest` 5, `AuthControllerTest` 4, `SecurityIntegrationTest` 4, `RepositoryIntegrationTest` 1, `BackendApplicationTests` 1) |
| Flutter static analysis | `flutter analyze` (in `frontend/`) | **0 errors, 0 warnings**, 14 pre-existing `unnecessary_underscores` infos |
| Flutter tests | `flutter test` | **9 tests passing** |
| Toolchain | — | Flutter 3.47.8 / Dart 3.x, Maven 3.9.12, Java 21, Spring Boot 4.1.1 |

Not executable in this environment: live Cognito sign-up/verification, RDS connectivity, S3, EC2/systemd, GPS on a device. Those items are marked **Blocked** or **Requires Manual Verification**, never "passed".

---

## 1. Architecture facts established from code

- **Frontend**: single active app at `frontend/lib/app/app.dart` (≈4.9k lines) holding the router, Riverpod providers, and all screens. Cognito through Amplify (`frontend/lib/features/auth/data/cognito_auth_service.dart`); tokens in `flutter_secure_storage`; access tokens (not ID tokens) are sent as `Authorization: Bearer`.
- **Backend**: `controller → service → repository` with a single shared `PlatformService` implementing the rules. Stateless Spring Security; Cognito JWT validated against the pool's JWKS, `token_use` must be `access`, principal = `sub`. When `COGNITO_ENABLED` is false the server denies **all** `/api/**` requests (fail-safe).
- **Identity**: `users.cognito_sub` is the mapping from Cognito to the local profile; client-supplied user ids are never trusted for ownership.
- **Database**: Flyway `V1__create_initial_schema.sql`; prod uses `ddl-auto=validate`, dev defaults to `update`.

---

## 2. Findings

Severity reflects impact if exploited or triggered: **Critical** = privilege bypass; **High** = auth/deployment breakage or cross-user effect; **Medium** = wrong data, missing validation, or misleading behaviour; **Low** = maintainability/UX.

### SEC-01 — A vehicle owner can confirm their own booking — **Critical** — **Completed**

- **Component**: Spring Boot / authorization.
- **Files**: `backend/.../service/PlatformService.java` (`transition`, `booking`), `backend/.../service/BookingService.java` (`cancel`, `confirm`, `reject`).
- **Evidence**: `booking(sub,id)` authorises when the caller is **either** the seeker or the station owner. `transition(sub,id,status)` was the single implementation behind `PUT /api/bookings/{id}/cancel`, `/confirm` and `/reject`, and only checked `status == PENDING`.
- **Actual behaviour**: `PUT /api/bookings/{id}/confirm` with the seeker's own token returned 200 and set `status=CONFIRMED`, bypassing provider approval. Symmetrically, a provider could `cancel` a seeker's booking, and a seeker could `reject` their own request.
- **Expected**: only the station owner may confirm/reject; only the seeker may cancel.
- **Root cause**: one ownership predicate reused for three different capabilities.
- **Fix applied**: replaced `transition` with `cancelBooking(sub,id)` (seeker only, `PENDING`/`CONFIRMED`) and `decideBooking(sub,id,status)` (station owner only, `PENDING` only, status restricted to `CONFIRMED`/`REJECTED`); `BookingService` now calls the correct one. `@Transactional` added so a failed decision does not leave a dirty entity.
- **Regression risk**: cancelling a `CONFIRMED` booking is now allowed for the seeker (previously impossible). Provider-side cancellation of a seeker booking is no longer possible by design.
- **Auto-fixable**: yes — done.
- **Verification**: new unit tests `seekerCannotConfirmOwnBooking`, `providerCanConfirmPendingBooking`, `providerCannotCancelSeekerBooking`, `seekerCancelsOwnPendingBooking` — all pass.

### SEC-02 — Role-less profiles could create both vehicles and stations — **High** — **Completed**

- **Component**: Spring Boot / authorization.
- **File**: `backend/.../service/PlatformService.java` (`requireRole`).
- **Evidence**: `if (user.getRole() != null && !required.equals(user.getRole())) throw forbidden();` — a `null` role short-circuits the check for **both** `saveVehicle` and `saveStation`.
- **Actual behaviour**: an account whose `users.role` is `NULL` could publish a charging station (and also create vehicles), i.e. both sides of the marketplace.
- **Expected**: a profile must have exactly one role before creating role-specific records.
- **Fix applied**: `null` role now throws `403` with an actionable message. Client compensates in FE-01 by assigning a role to legacy profiles at sign-in. Backfill SQL for existing rows is in §5.
- **Regression risk**: legacy `role IS NULL` rows are blocked until a role is assigned (intended). New users are unaffected — the app always sends a role when creating the profile.
- **Verification**: `rejectsVehicleCreationWhenProfileHasNoRole`, `rejectsStationCreationForVehicleOwnerRole`, `allowsStationCreationForProviderRole` pass.

### SEC-03 — `/api/stations/mine` fell through to a public matcher — **High** — **Completed (inspection-verified)**

- **Component**: Spring Boot / Spring Security.
- **File**: `backend/.../security/SecurityConfig.java`.
- **Evidence**: the public block permits `GET /api/stations`, `/api/stations/nearby`, `/api/stations/{id}`, `/api/stations/{id}/availability`. `{id}` matches **any** single segment, including the literal `mine`, and `"/api/stations/mine"` was not listed earlier.
- **Actual behaviour**: anonymous `GET /api/stations/mine` was authorised by the filter chain and only rejected because `StationController.mine` calls `CurrentUser.subject(null)` → 401. The endpoint therefore depended on a controller-side check for a security decision.
- **Expected**: authentication required at the filter chain.
- **Fix applied**: explicit `.requestMatchers(HttpMethod.GET, "/api/stations/mine").authenticated()` placed **before** the public station matchers (first match wins).
- **Verification**: compile + full test suite pass. **Not** covered by an automated test — `SecurityIntegrationTest` uses standalone MockMvc without the security chain, and the Cognito chain needs a live JWKS endpoint (see TST-01).

### SEC-04 — Image upload endpoint returned a fabricated upload URL — **Medium** — **Completed**

- **Component**: Spring Boot / API contract.
- **File**: `backend/.../controller/StationImageController.java` (`uploadUrl`).
- **Evidence**: returned `{"uploadUrl": "/api/stations/{id}/images", "s3ObjectKey": "<uuid>-<fileName>", "note": "Configure S3 presigned URLs before production"}` without contacting S3.
- **Actual behaviour**: a client following that URL `POST`s metadata to the images endpoint, not bytes to S3. Nothing is stored in S3, yet the key was recorded in `station_images` — an image row pointing at an object that does not exist.
- **Fix applied**: the endpoint now returns `501 Not Implemented` with an explicit message, so no client can mistake it for a working upload. The intended contract is documented in `docs/API.md` as **not implemented**.
- **Remaining work**: implement real presigned uploads (see TASK-13). Requires an S3 bucket, a task role with `s3:PutObject`, and `S3_BUCKET`/`AWS_REGION` server-side configuration.

### SEC-05 — Onboarding completion was self-asserted — **Medium** — **Completed**

- **Component**: Spring Boot / data integrity.
- **File**: `backend/.../service/PlatformService.java` (`updateOnboarding`).
- **Evidence**: `PUT /api/users/me/onboarding` accepted `{"onboardingCompleted": true}` and persisted it with no role check and no role-specific record check.
- **Actual behaviour**: any client could mark onboarding complete and skip vehicle/station creation; the flag is what the frontend uses to decide between `/account-setup` and the dashboard.
- **Fix applied**: completing now requires an assigned role **and** at least one vehicle (`VEHICLE_OWNER`) or station (`CHARGER_PROVIDER`); otherwise `400` with the reason.
- **Regression risk**: order matters — the app already creates the vehicle/station before calling this endpoint, so the existing flow is unaffected.
- **Verification**: `rejectsOnboardingCompletionWithoutRoleRecords`, `completesOnboardingWhenTheVehicleExists` pass.

### SEC-06 — No Cognito app-client (`aud`/`client_id`) restriction — **Medium** — **Open**

- **File**: `backend/.../security/SecurityConfig.java` (`jwtDecoder`, `accessTokenValidator`).
- **Evidence**: the decoder validates signature, issuer, expiry and `token_use=access` only.
- **Impact**: any access token issued by the same user pool — including a token minted for an unrelated app client added later — is accepted. Low today (one pool, one client), but it is a missing trust boundary.
- **Recommended fix**: add an allow-list validator comparing `client_id` to `COGNITO_APP_CLIENT_ID` (env var), failing closed when unset in `prod`.
- **Needs user**: the app client id value; safe to add to the EC2 environment file.
- **Verification**: unit test on the validator with mismatched `client_id`.

### SEC-07 — No rate limiting or abuse controls — **Low** — **Open**

- **Evidence**: none of the controllers or the security chain rate-limit; Cognito's own throttling is the only limit on sign-in.
- **Recommended fix**: throttle at the ALB/WAF or add a request-rate filter for `POST /api/bookings` and profile writes.

### SEC-08 — `/api/auth/me` echoes token metadata — **Low** — **Open**

- **File**: `backend/.../controller/AuthController.java`.
- **Evidence**: the response includes `tokenUse`, `clientId`, `username` and `email` claims in addition to the profile.
- **Impact**: not secret, but unnecessary attack surface and easy to confuse with privileged data.
- **Recommended fix**: return only `localId`, `fullName`, `role`, `onboardingCompleted`, `profileCreated`.

### DATA-01 — Estimated cost was the unit price, not the session cost — **Medium** — **Completed**

- **File**: `backend/.../service/PlatformService.java` (`createBooking`).
- **Evidence**: `if(s.getPricePerKwh()!=null) b.setEstimatedCost(s.getPricePerKwh());`
- **Actual behaviour**: a 2-hour booking at ₹10/kWh stored `estimated_cost = 10.00`, which the app shows as the estimated total.
- **Expected**: `pricePerKwh × durationInHours`, rounded to 2 decimals.
- **Fix applied**: `estimateCost(station, start, end)` computes hours from `Duration.between`, multiplies and rounds `HALF_UP`; returns `null` when the price is unset or the window is non-positive.
- **Verification**: `estimatesCostFromDurationNotUnitPrice` (2 h × 10.00 → `20.00`) passes.

### DATA-02 — Missing ids produced 500 instead of 400 — **Medium** — **Completed**

- **Evidence**: `createBooking` called `ownedVehicle(sub, null)` → `findById(null)` → `InvalidDataAccessApiUsageException` → 500.
- **Fix applied**: explicit `400` for a missing `vehicleId` or `stationId` before any repository call.
- **Verification**: `rejectsBookingWithoutVehicleId` passes.

### DATA-03 — Availability updates could overlap existing windows — **Medium** — **Completed**

- **Evidence**: `addWindow` rejected overlaps; `updateWindow` only validated `end > start`.
- **Impact**: a provider could edit a window onto another, producing double-bookable slots that `createBooking` then treats as one contiguous availability.
- **Fix applied**: added `existsByStationIdAndIdNotAndStartTimeLessThanAndEndTimeGreaterThan` to `ChargerAvailabilityRepository` and an overlap check in `updateWindow` (409).
- **Verification**: covered by compilation and the regression suite; no dedicated unit test (the repository method is derived and exercised only against a real DB).

### DATA-04 — Nearby search has no ceiling and no spatial index — **Medium** — **Partially Completed**

- **File**: `backend/.../service/PlatformService.java` (`nearby`).
- **Evidence**: only `radius <= 0` was rejected; the implementation calls `findByActiveTrue()` and filters/sorts the whole table in memory.
- **Fix applied**: radius is now capped at **50 km** (`MAX_SEARCH_RADIUS_KM`, matching the mobile client), so a single request can no longer scan arbitrary distances with an unbounded result set.
- **Remaining**: the query is still `O(active stations)`. For growth, add PostGIS (`geography(Point,4326)` + `ST_DWithin`) or a bounding-box `WHERE` clause with an index on `(latitude, longitude)`.
- **Verification**: `rejectsNearbyRadiusAboveTheCap` passes; the existing `returnsNearbyStationsNearestFirst` still passes.

### DATA-05 — Inactive stations 404 on the public detail route — **Low** — **Open**

- **Evidence**: `station(id)` = `findById(id).filter(isActive)`; `GET /api/stations/{id}` is public.
- **Impact**: a provider following a deep link to their own hidden listing gets "Station not found". Owner flows (`/mine`, `PUT`, availability) use `findById`, so management still works.
- **Recommended fix**: keep the public 404 for anonymous callers, but return hidden stations to their owner when a valid token is present.

### DATA-06 — No provider-wide booking list — **Low** — **Open**

- **Evidence**: `GET /api/bookings` → `findBySeekerUserId`. `GET /api/stations/{id}/bookings` is the only provider view, so the app fans out per station (`ProviderBookingsScreen`).
- **Recommended fix**: `GET /api/bookings/received` joining `bookings.station_id → charging_stations.owner_user_id`.

### DATA-07 — Session history is seeker-only — **Low** — **Open**

- **Evidence**: `mySessions` maps the caller's seeker bookings to sessions. A provider sees no sessions for their own stations, although `startSession`/`completeSession` accept the station owner.
- **Recommended fix**: union of seeker and station-owner sessions, or a provider-specific endpoint.

### CFG-01 — Documented `DB_URL` was ignored by the application — **High** — **Completed**

- **Files**: `backend/src/main/resources/application.properties`, `backend/README.md`, `README.md`, `AWS_DEPLOYMENT_GUIDE.md`, systemd unit example.
- **Evidence**: every deployment instruction sets `DB_URL=...`, but the property was the literal `spring.datasource.url=jdbc:postgresql://localhost:5432/evfleetdb` with no `${DB_URL}` placeholder. Only `SPRING_DATASOURCE_URL` (relaxed binding) would have had an effect.
- **Actual behaviour**: a production host configured exactly as documented keeps connecting to `localhost:5432` and fails at startup (or, worse, to a local PostgreSQL that happens to exist).
- **Fix applied**: `spring.datasource.url=${DB_URL:jdbc:postgresql://localhost:5432/evfleetdb}`. `SPRING_DATASOURCE_URL` still overrides it (environment variables take precedence over `application.properties`), so existing deployments are not broken.
- **Verification**: configuration-only; confirmed by inspection and a clean `mvn test` context startup. **Runtime confirmation against RDS is not possible here.**

### CFG-02 — Flyway could fail on an existing development database — **Medium** — **Completed**

- **Evidence**: `spring-boot-starter-flyway` is on the classpath, so Flyway runs by default, but `baseline-on-migrate` was set **only** in `application-prod.properties`. A dev database previously created by `ddl-auto=update` has tables and no `flyway_schema_history` → startup aborts.
- **Fix applied**: `spring.flyway.baseline-on-migrate=${FLYWAY_BASELINE_ON_MIGRATE:true}` and `baseline-version=0` in `application.properties`, so the behaviour is identical across profiles and overridable.
- **Note**: baselining an existing schema assumes it already matches V1. Verify with `ddl-auto=validate` before relying on it.

### CFG-03 — `DDL_AUTO` still defaults to `update` — **Medium** — **Open**

- **Evidence**: `spring.jpa.hibernate.ddl-auto=${DDL_AUTO:update}` in `application.properties`; `validate` only in the `prod` profile.
- **Impact**: if `SPRING_PROFILES_ACTIVE=prod` is missing on EC2, Hibernate silently alters the RDS schema — schema drift with no migration record.
- **Recommended fix**: after confirming V1 covers the entities, switch the default to `validate` and require Flyway everywhere.
- **Needs user**: a maintenance window to confirm the deployed schema matches V1.

### CFG-04 — Plain-HTTP backend default — **Medium** — **Open**

- **Evidence**: `ApiConstants.apiBaseUrl` defaults to the EC2 address over `http://`; `android/app/src/main/res/xml/network_security_config.xml` allows cleartext only for that host.
- **Impact**: tokens and profile data travel unencrypted in debug builds. Release builds refuse non-loopback HTTP through the startup configuration gate, so this cannot ship as-is — but it is still the documented default.
- **Recommended fix**: terminate TLS at ALB/CloudFront, set `API_BASE_URL` to the `https://` origin, delete the cleartext exception.
- **Needs user**: an ACM certificate and DNS.

### CFG-05 — JWT discovery makes startup depend on Cognito reachability — **Low** — **Open**

- **Evidence**: `JwtDecoders.fromIssuerLocation(issuerUri)` performs OIDC discovery during bean creation.
- **Impact**: an outbound-network problem at boot prevents the API from starting, even though token validation would work later.
- **Recommended fix**: `NimbusJwtDecoder.withJwkSetUri(issuerUri + "/.well-known/jwks.json")`, or a retrying `JwtDecoder` bean; keep an actuator health indicator for Cognito.

### FE-01 — Legacy profiles without a role could not recover — **Medium** — **Completed**

- **File**: `frontend/lib/app/app.dart` (`_signIn`).
- **Evidence**: the profile was only created when `me['profileCreated'] == false`. A profile with `role == null` was never repaired, so `_role` stayed `null` and the router sent the user back to `/login` forever — and with SEC-02 fixed, such an account could not create anything either.
- **Fix applied**: sign-in now also calls `saveProfile(..., role: ...)` when the backend reports no role. The backend only accepts a role while the stored one is empty, so existing roles are never overwritten.
- **Verification**: `flutter analyze` clean, `flutter test` 9/9. **Not** exercised against a live Cognito account (no credentials).

### FE-02 — Router, providers and every screen live in one file — **Low** — **Open**

- **Evidence**: `frontend/lib/app/app.dart` ≈4.9k lines; `frontend/lib/features/**` is legacy and unused by the active app.
- **Impact**: review cost, merge conflicts, and accidental coupling (any change recompiles everything).
- **Recommended fix**: split `app.dart` into `router/`, `providers/`, `screens/`, `widgets/` following the existing `features/` layout, then delete the unused legacy tree.

### FE-03 — 14 `unnecessary_underscores` info lints — **Low** — **Open**

- **Evidence**: `(_, __) => ...` in GoRoute builders (`flutter analyze`). Harmless; matches the existing style.

### FE-04 — No tests for API mapping, booking or location failures — **Medium** — **Open**

- **Evidence**: `frontend/test/` covers `error_handler` (6) and routing/guard (3). Nothing tests `BackendApiService` JSON mapping, the booking flow, or `LocationStatus` → message mapping.
- **Recommended fix**: inject a fake `Dio`/adapter and assert request paths, bodies and error mapping; widget-test `SetupScreen` location failures with a fake `LocationService`.

### FE-05 — Navigation entries for unconnected features — **Low** — **Open**

- **Evidence**: charging history, station images and provider contact are presented but explicitly answer "not connected" (`_showMessage`).
- **Impact**: acceptable for an MVP because the labels are honest; remove or disable them before a wider release.

### TST-01 — Security matcher list is not covered by a test — **Medium** — **Open**

- **Evidence**: `SecurityIntegrationTest` builds standalone MockMvc without the filter chain; the Cognito chain needs a live issuer. SEC-03 therefore has no regression test.
- **Recommended fix**: slice test with `@WebMvcTest` + a mocked `JwtDecoder` bean and `app.cognito.enabled=true`, asserting 401 for `/api/stations/mine` and 200 for `/api/stations`.

### TST-02 — No PostgreSQL integration test — **Low** — **Open**

- **Evidence**: `application-test.properties` uses H2 `MODE=PostgreSQL` with `create-drop`; Flyway's SQL is therefore never validated against a real engine.
- **Recommended fix**: Testcontainers `postgres:16` for `RepositoryIntegrationTest`, running Flyway then `validate`.

---

## 3. Prioritized task list

Ordered by security → data integrity → authentication/onboarding → integration → stability → maintainability, with dependencies made explicit.

| ID | Priority | Task | Depends on | Status |
|---|---|---|---|---|
| SEC-01 | 1 | Role-specific booking transitions | — | **Completed** |
| SEC-02 | 2 | Reject role-less record creation | — | **Completed** |
| SEC-03 | 3 | Protect `/api/stations/mine` in the filter chain | — | **Completed** |
| SEC-05 | 4 | Require role + record to complete onboarding | SEC-02 | **Completed** |
| SEC-04 | 5 | Stop returning a fake S3 upload URL | — | **Completed** |
| CFG-01 | 6 | Honour `DB_URL` (deployment blocker) | — | **Completed** |
| DATA-01 | 7 | Correct `estimatedCost` calculation | — | **Completed** |
| DATA-02 | 8 | 400 instead of 500 for missing booking ids | — | **Completed** |
| DATA-03 | 9 | Overlap check on availability update | — | **Completed** |
| FE-01 | 10 | Repair null-role profiles at sign-in | SEC-02 | **Completed** |
| DATA-04 | 11 | Cap nearby radius (done) → PostGIS / bbox query | — | **Partially Completed** |
| CFG-02 | 12 | Flyway baseline in all profiles | — | **Completed** |
| SEC-06 | 13 | Validate Cognito `client_id` | app client id | **Open** |
| CFG-03 | 14 | Default `ddl-auto=validate` | schema confirmation | **Open** |
| CFG-04 | 15 | HTTPS origin for the API | ACM + DNS | **Blocked** (user) |
| TASK-13 | 16 | Real S3 presigned uploads | bucket + IAM role | **Blocked** (user) |
| TST-01 | 17 | Security slice test with mocked decoder | — | **Open** |
| FE-04 | 18 | Frontend API/flow/location tests | — | **Open** |
| DATA-05 | 19 | Owner-visible inactive station detail | SEC-03 | **Open** |
| DATA-06 | 20 | Provider-wide booking list | — | **Open** |
| DATA-07 | 21 | Provider session history | — | **Open** |
| SEC-08 | 22 | Trim `/api/auth/me` response | — | **Open** |
| SEC-07 | 23 | Rate limiting / WAF | AWS access | **Open** |
| CFG-05 | 24 | Resilient JWKS decoder | — | **Open** |
| FE-02 | 25 | Split `app.dart`; delete legacy tree | — | **Open** |
| FE-03 | 26 | Fix `unnecessary_underscores` lints | — | **Open** |
| FE-05 | 27 | Remove/disable unconnected nav entries | — | **Open** |
| TST-02 | 28 | Testcontainers PostgreSQL integration test | Docker | **Open** |

---

## 4. Changes made in this pass

| File | Change |
|---|---|
| `backend/.../service/PlatformService.java` | Strict role check; `cancelBooking`/`decideBooking`; booking id validation; duration-based `estimatedCost`; 50 km radius cap; availability overlap on update; onboarding completion precondition |
| `backend/.../service/BookingService.java` | Routes cancel/confirm/reject to the correct capability |
| `backend/.../repository/ChargerAvailabilityRepository.java` | Added overlap-excluding existence query |
| `backend/.../controller/StationImageController.java` | Upload URL now answers `501` instead of a fabricated URL |
| `backend/.../security/SecurityConfig.java` | `/api/stations/mine` requires authentication before the public matchers |
| `backend/src/main/resources/application.properties` | `${DB_URL:...}`; Flyway baseline defaults |
| `backend/src/test/.../PlatformServiceTest.java` | Role in fixture; 12 new tests (39 total) |
| `frontend/lib/app/app.dart` | Sign-in repairs a missing backend role |

## 5. Manual actions required

1. **Backfill legacy roles** (run once, after backup; replace the email/role pairs with real ones):
   ```sql
   -- Inspect the affected accounts first
   SELECT id, email, full_name, role FROM users WHERE role IS NULL;
   -- Assign the correct role per account (never blanket-update blindly)
   UPDATE users SET role = 'VEHICLE_OWNER' WHERE id = <id> AND role IS NULL;
   ```
   The application can also repair a role at next sign-in, but only for accounts that sign in.
2. **Confirm the deployed schema matches V1** before setting `DDL_AUTO=validate`.
3. **Set `DB_URL`** (now honoured) or `SPRING_DATASOURCE_URL` in the EC2 environment file and restart; verify `/actuator/health` and one authenticated call.
4. **Provide the Cognito app client id** if SEC-06 should be enforced.
5. **Decide on S3** (TASK-13): bucket, IAM task role, CORS, and `S3_BUCKET`/`AWS_REGION` in the environment.

No AWS resource, deployment, credential or production database was modified during this audit.
