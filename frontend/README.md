# EV Fleet Intelligence — Flutter frontend

Peer-to-peer EV charging discovery and booking. This folder is the Flutter client for the Spring Boot + PostgreSQL
backend in [`../backend`](../backend). Charging providers list chargers at fixed coordinates; vehicle users find
them by radius, book a slot, and providers confirm or reject the request.

- API contract: [`docs/API_INTEGRATION.md`](docs/API_INTEGRATION.md)
- AWS values and where to get them: [`docs/AWS_CONFIGURATION_GUIDE.md`](docs/AWS_CONFIGURATION_GUIDE.md)
- Honest feature-by-feature status: [`docs/INTEGRATION_STATUS.md`](docs/INTEGRATION_STATUS.md)
- Configuration template: [`.env.example`](.env.example)

Package name: `evfleet_frontend`. Entry point: [`lib/main.dart`](lib/main.dart) → [`lib/app/app.dart`](lib/app/app.dart).

---

## Prerequisites

- Flutter SDK `^3.13.5` (Dart 3), with Android toolchain for device builds.
- The Spring Boot backend reachable over HTTP(S), with Cognito JWT validation enabled.
- A Cognito **public** app client (no client secret) with e-mail verification enabled.

## Configure

```bash
cp .env.example .env      # .env is git-ignored
# edit .env: API_BASE_URL, AWS_REGION, COGNITO_USER_POOL_ID, COGNITO_APP_CLIENT_ID
```

`.env` is read with `--dart-define-from-file`. Missing values are reported at startup by a
"Configuration needed" screen that lists each absent key and where to obtain it; nothing is silently defaulted
except the sample API origin.

## Run

```bash
flutter pub get
flutter run --dart-define-from-file=.env
```

Android emulator: `localhost` in `API_BASE_URL` is rewritten to `10.0.2.2` automatically. On a physical device use
the development machine's LAN address, e.g. `--dart-define=API_BASE_URL=http://192.168.1.25:8080`.

```bash
# Installable release APK
flutter build apk --release --dart-define-from-file=.env
# output: build/app/outputs/flutter-apk/app-release.apk
```

`--dart-define=DEMO_MODE=true` serves the in-memory sample dataset. It is the **only** way to get sample data —
a failed request never falls back to it, so an outage always surfaces as an error state.

## Test

```bash
dart format lib test
flutter analyze
flutter test
```

Current state: `flutter analyze lib` reports 0 errors (only pre-existing `unnecessary_underscores` info lints) and
`flutter test` passes 7/7. Live flows against AWS are **not** covered yet — see `docs/INTEGRATION_STATUS.md`.

## How the pieces fit

```
lib/
  app/app.dart            # active UI: shell, dashboards, stations, bookings, provider tools
  core/config/            # startup configuration validation + missing-config screen
  core/constants/         # API base URL, Cognito keys, REST paths (all via --dart-define)
  core/network/           # Dio client, bearer-token interceptor, BackendApiService
  core/errors/            # DioException → user-safe AppException
  core/utils/             # geolocation wrapper, formatters, validators
  features/auth/data/     # Amplify Cognito adapter (sign-up, verify, sign-in, reset, restore)
  features/**             # domain/data layers; only the auth adapter + shared widgets are
                          # referenced by the active UI (kept, not wired)
```

State management is Riverpod (`FutureProvider` for reads, `Notifier` for the search radius),
navigation is GoRouter, HTTP is Dio.

- **Auth:** Cognito access tokens are attached as `Authorization: Bearer`. A `401` clears the local session and
  returns to sign-in. ID tokens are rejected by the backend, so only the access token is sent.
- **Identity:** the backend derives the user from the validated `sub` claim. `userId`, `ownerUserId`, `seekerUserId`
  and `role` values sent by the client are ignored/overwritten server-side.
- **Nearby search:** with a device location the client calls `GET /api/stations/nearby?latitude&longitude&radiusKm`
  (server-side filter, sorted by distance, active stations only). Without one it shows the public catalogue and
  leaves distances blank rather than inventing them.

## Implemented screens

- **Startup:** session restore with a 20 s timeout and a recovery screen; configuration gate when keys are missing.
- **Auth:** sign-in, sign-up, e-mail verification (with resend), forgot/reset password, sign-out.
- **Role selection** with server-side persistence (`PUT /api/users/me/onboarding`).
- **Vehicle onboarding:** profile + first vehicle; **provider onboarding:** profile + first station with GPS.
- **Vehicle user:** home (real counts, next booking), explore (radius search, list toggle), station details,
  booking flow, my bookings (cancel), my vehicles (add/delete), profile (view/edit).
- **Provider:** dashboard, my chargers (publish/hide listing, publish/delete availability windows),
  booking requests with Confirm/Reject.

## Known limitations

- No map provider is configured; the map tab is a placeholder surface (no `MAP_PROVIDER_KEY` needed yet).
- Station images: the backend's S3 `upload-url` endpoint is a stub, so no upload path exists.
- Charging sessions/history, notifications and in-app provider contact are explicitly "not connected" states.
- Vehicle edit and station edit/delete call no endpoint yet, although the backend supports them.
- The legacy feature tree under `lib/features/**` is retained but not wired into the active UI.

## Security notes

- Never put an AWS secret key, database password or Cognito client secret in this app or in `.env`.
- Production must use HTTPS: release builds reject plaintext HTTP except loopback hosts.
  `android/app/src/main/res/xml/network_security_config.xml` currently whitelists the plain-HTTP demo host —
  remove that before a real release.
- No password, token or full request body is logged.
