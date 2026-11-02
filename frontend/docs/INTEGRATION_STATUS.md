# Integration Status — EV Fleet Intelligence frontend

Legend for **Test result**:

- **Unit/widget** — covered by `flutter test` (ran, passing).
- **Not run** — implemented but not exercised against a live backend in this environment.
- **Blocked** — needs real AWS resources, a device, or backend work that does not exist yet.

Local checks that were actually executed:

| Command | Result |
| --- | --- |
| `flutter pub get` | Passed (dependencies resolved) |
| `flutter analyze lib` | Passed — 0 errors; 14 pre-existing `unnecessary_underscores` info lints |
| `flutter test` | Passed — 7/7 tests |

No end-to-end run against the deployed backend was performed in this environment (no Cognito test user, no device).

---

## Feature status

| Feature | Frontend implementation | Backend endpoint status | AWS dependency | Test result | Remaining work |
| --- | --- | --- | --- | --- | --- |
| Sign-in (e-mail + password, SRP) | Done — Amplify `signIn` | Cognito only | Cognito pool + public app client | Not run | Needs a real test user |
| Sign-up + e-mail verification + resend | Done — `signUp`, `confirmSignUp`, `resendSignUpCode` | Cognito only | E-mail verification enabled on the pool | Not run | Real inbox check |
| Forgot / reset password | Done — `resetPassword`, `confirmResetPassword` | Cognito only | Cognito pool | Not run | Real inbox check |
| Session restore + refresh | Done — `fetchAuthSession` on startup, 20 s timeout, recovery screen | Cognito only | Cognito pool | Unit/widget (startup paths) | — |
| Sign-out | Done — clears Amplify session + local prefs | Cognito only | Cognito pool | Not run | — |
| Role selection (vehicle / provider) | Done — role persisted via backend, never trusted from local state alone | `PUT /api/users/me`, `PUT /api/users/me/onboarding` | Backend `COGNITO_ENABLED=true` | Not run | Backend role backfill for older rows (see below) |
| Vehicle onboarding (profile + vehicle) | Done, with per-step error surfacing | `PUT /api/users/me` → `POST /api/vehicles` → onboarding | Backend JWT validation | Not run | Rollback/retry for partially created data |
| Provider onboarding (profile + station + GPS) | Done — "Use current location" via `geolocator`, manual address fallback, coordinates never defaulted to zero | `POST /api/stations` (validates lat/lng + `powerKw`) | Backend JWT validation, location permission | Widget (location denial messaging) | No map pin adjustment (no map SDK configured) |
| Onboarding resume after restart | Done — `onboardingCompleted` re-read from `/api/auth/me`; local cache only a fallback | `GET /api/auth/me` | Backend JWT validation | Not run | — |
| Vehicle user home | Done — real station count, next booking, quick actions | `GET /api/stations`, `GET /api/bookings` | — | Not run | — |
| Explore / nearby search | Done — **server-side** radius query (`/api/stations/nearby`), radius 1/5/10/25/50 km, list + placeholder map | `GET /api/stations/nearby` (public, sorted by distance, active only) | None | Not run | Real map SDK; connector/price filters not wired |
| Station details | Done — real fields, availability windows, distance label | `GET /api/stations/{id}`, `GET /api/stations/{id}/availability` | — | Not run | Images (`GET .../images` needs a token and is unused) |
| Booking request | Done — vehicle picker, window picker, `409` handling, status from server | `POST /api/bookings` (validates ownership, connector, availability, overlap) | Backend JWT validation | Not run | Estimated cost shown only as returned |
| My bookings + cancel | Done — grouped by real statuses (`PENDING`/`CONFIRMED`/`REJECTED`/`CANCELLED`) | `GET /api/bookings`, `PUT /api/bookings/{id}/cancel` | Backend JWT validation | Not run | No `COMPLETED` state exists in the API |
| My vehicles (list/add/delete) | Done | `GET/POST/DELETE /api/vehicles` | Backend JWT validation | Not run | Edit vehicle uses `PUT /api/vehicles/{id}` — **not wired in the UI** |
| Profile view/edit | Done | `GET/PUT /api/users/me` | Backend JWT validation | Not run | — |
| Provider dashboard | Done — station count, real requests via per-station endpoints | `GET /api/stations/mine`, `GET /api/stations/{id}/bookings` | Backend JWT validation | Not run | Charging history still an explicit "not connected" state |
| Provider: my chargers | Done — list, publish/hide toggle, availability publish/delete | `GET /api/stations/mine`, `PUT /api/stations/{id}/status`, `POST/DELETE .../availability` | Backend JWT validation | Not run | Station **edit** (`PUT /api/stations/{id}`) and **delete** not wired in the UI |
| Provider: booking requests | Done — per-station requests, Confirm/Reject, server state re-read | `PUT /api/bookings/{id}/confirm`, `/reject` | Backend JWT validation | Not run | No push/real-time refresh |
| Provider availability edit | Partially done — publish + delete windows | `POST`/`DELETE` used; `PUT .../availability/{windowId}` unused | Backend JWT validation | Not run | Window editing UI |
| Charging sessions / history | Not implemented — explicit "not connected in this build" message | Endpoints exist (`/api/bookings/{id}/sessions`, `/api/sessions/*`) | Backend JWT validation | Blocked | Full session start/complete UI |
| Station images (S3) | Not implemented — no picker/upload UI | `upload-url` is a **stub**, no S3 config, no presigned URLs | Needs S3 bucket + IAM + signing code | Blocked | Backend presign implementation, then client upload |
| Contact provider | Not implemented — no phone/messaging action is exposed | No contact endpoint exists | — | Blocked | Decide mechanism (e.g. `tel:` with owner-consented number) |
| Notifications | Not implemented — demo repo only, not wired | No notifications endpoint | — | Blocked | Backend endpoint + client list |
| Configuration validation | Done — startup gate lists each missing key with its AWS source; `[config]` log line | — | All client values | Widget (gate dismissal) | — |

---

## Backend work still required

1. **S3 presigned uploads.** `StationImageController.uploadUrl` returns a placeholder object, not a signed URL,
   and no bucket/region is configured. Until this exists, images cannot be uploaded from any client.
2. **Role enforcement for legacy rows.** `PlatformService.requireRole` only rejects a *mismatched* role; a user with
   `role == null` can create both vehicles and stations. Backfill roles and make the check strict
   (`if (!required.equals(user.getRole())) throw forbidden();`).
3. **Provider-wide booking list.** `GET /api/bookings` returns only bookings where the caller is the seeker, so the
   provider UI has to call `GET /api/stations/{id}/bookings` once per station. A single
   `GET /api/provider/bookings` would remove that fan-out.
4. **Booking completion state.** Bookings never reach `COMPLETED`; completion lives on charging sessions, which the
   client cannot create without a full session UI.
5. **Inactive station visibility for owners.** `GET /api/stations/{id}` returns `404` for inactive stations, so an
   owner cannot re-open their own hidden listing by id (the provider UI works around it via `/mine`).
6. **Contact mechanism.** No endpoint or field exposes a provider contact method for vehicle users.
7. **HTTPS.** The current default API origin is plain HTTP (`http://13.204.143.82:8080`). Release builds require TLS.

---

## What was verified by hand

- `flutter analyze lib` → 0 errors.
- `flutter test` → 7/7 passing (`error_handler_test.dart` ×6, widget flow test ×1).
- `config/app_config.dart` returns exactly `AWS_REGION, COGNITO_USER_POOL_ID, COGNITO_APP_CLIENT_ID` as missing in
  this build (confirmed by the `[config]` startup log line in the test output).
- Endpoint shapes, status codes, sorting and validation rules were read from the backend source, not assumed.

## What was **not** verified

- Any real sign-in/sign-up/verification against Cognito.
- Any live API call (nearest search, booking creation, provider confirm/reject) against the deployed backend.
- Location permission behaviour on a physical Android/iOS device.
- Push of provider decisions changing the vehicle user's list without a manual refresh.
