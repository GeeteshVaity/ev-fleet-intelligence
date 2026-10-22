# Voltway EV charging app

Voltway is the Flutter UI foundation for the EV Fleet Intelligence charging
platform. The current build is intentionally **demo mode**: stations, vehicles,
bookings, and the signed-in profile come from in-memory Riverpod providers.
No credentials, tokens, or fake backend success responses are stored.

## Run locally

```powershell
cd evfleet_mobile
flutter pub get
flutter run
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
