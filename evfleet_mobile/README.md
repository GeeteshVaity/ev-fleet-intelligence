# Voltway EV charging app

Voltway is the Flutter client for the EV Fleet Intelligence charging platform.
The authentication and onboarding flow connects to the Spring Boot backend.

## Run locally

```powershell
cd evfleet_mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8080
```

For a real Cognito session, provide the existing User Pool values at run time:

```powershell
flutter run `
  --dart-define=API_BASE_URL=http://localhost:8080 `
  --dart-define=COGNITO_USER_POOL_ID=<region>_<user-pool-id> `
  --dart-define=AWS_REGION=<region> `
  --dart-define=COGNITO_APP_CLIENT_ID=<public-app-client-id>
```

The app sends Cognito access tokens (not ID tokens) as bearer credentials.
The backend requires the matching issuer
`https://cognito-idp.<region>.amazonaws.com/<user-pool-id>`, discovers its
signing keys, and rejects expired, wrong-issuer, invalid-signature, and ID
tokens. Never put a client secret or AWS credentials in Flutter build defines.

For Flutter web, set the backend `FRONTEND_ORIGIN` to the exact browser origin
shown by the Flutter dev server (for example `http://localhost:3000`); do not
use `*`. Native Android and iOS clients do not require browser CORS.

When running on an Android emulator, the app automatically maps `localhost` to
the host machine's `10.0.2.2` address. For a physical device, use the
development computer's LAN address instead, for example:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.25:8080
```

Validation:

```powershell
dart format lib test
flutter analyze
flutter test
```

## Implemented screens

- Home dashboard with nearby station cards, quick actions, and upcoming booking.
- Explore list and demo map view with station search.
- Station details and booking request flow with vehicle, date, and time selection.
- Bookings list with pending, confirmed, and completed status badges.
- Vehicles list.
- Profile, sign-out demo action, and settings/notifications placeholders.
- Sign-in entry point explicitly labeled as demo mode.
- Not-found route.

The active demo entry point is [lib/app/app.dart](lib/app/app.dart), with
[lib/main.dart](lib/main.dart) responsible only for bootstrapping Riverpod.
The legacy feature tree remains in the workspace but is excluded from analysis
until it is migrated behind the active repository interfaces.

## Dependencies

The project already includes the planned integration dependencies:
Riverpod, GoRouter, Dio, secure storage, Geolocator, cached network images,
SharedPreferences, and Intl. The active UI currently needs Riverpod, GoRouter,
and Intl; the remaining packages are retained for the integration phase.

## Backend integration checklist

1. Confirm Cognito region, User Pool ID, and public app client ID.
2. Implement the auth repository behind the existing UI abstraction using
   authorization code + PKCE; never ship an app client secret or IAM keys.
3. Store access and refresh tokens only in secure storage and add token refresh
   handling to the Dio interceptor.
4. Set the Spring Boot API base URL through build-time configuration rather than
   hardcoding a production URL.
5. Replace the demo station, vehicle, and booking providers with repository
   implementations and explicit loading/error/empty states.
6. Connect map tiles and device-location permission handling.
7. Confirm server-side ownership, authorization, availability, and booking
   conflict checks before enabling destructive or booking actions.
8. Add integration tests for Cognito flows and the Spring Boot API contract.

## Current limitations

- Demo data is not persisted and booking requests do not reach a server.
- Map rendering is a visual placeholder; no map provider key is configured.
- Owner management, full auth flows, charging history, and production settings
  still need their feature modules wired to the backend.
- The analyzer intentionally excludes the disconnected legacy feature tree while
  it is migrated; its pre-existing station-filter file still needs repair.
