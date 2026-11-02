# EV Fleet Intelligence --- Charging Provider App

## Overview

The **Charging Provider App** is the mobile application for people or
businesses that make EV charging facilities available to vehicle owners
through the EV Fleet Intelligence platform.

This application is being developed as a separate Flutter app from the
Vehicle User App. Both apps will live in the same GitHub repository and
communicate with the existing Spring Boot backend. The backend remains
responsible for authentication validation, authorization, business
logic, and database operations.

### Project structure

``` text
ev-fleet-intelligence/
├── backend/                         # Existing Spring Boot backend
├── mobile/
│   ├── charging_provider/            # Charging Provider Flutter app
│   └── vehicle_user/                 # Vehicle User Flutter app (develop later)
├── docs/
└── README.md
```

### Technology stack

  ------------------------------------------------------------------------
  Area                    Technology               Responsibility
  ----------------------- ------------------------ -----------------------
  Mobile framework        Flutter / Dart           Cross-platform mobile
                                                   application

  State management and    Riverpod                 Application state and
  dependency injection                             shared dependencies

  Navigation              GoRouter                 Centralized route
                                                   definitions and
                                                   navigation

  HTTP client             Dio                      Communication with
                                                   Spring Boot APIs

  Secure local storage    flutter_secure_storage   Secure storage of
                                                   authentication tokens

  Authentication          Amazon Cognito           Provider sign-in and
                                                   account authentication

  Backend                 Spring Boot              APIs, business rules,
                                                   authentication and
                                                   authorization

  Database                PostgreSQL (AWS RDS)     Persistent application
                                                   data
  ------------------------------------------------------------------------

------------------------------------------------------------------------

## Screen inventory

The initial Charging Provider application is planned around **18
screens**, grouped by feature.

### 1. App launch and authentication

  ------------------------------------------------------------------------------------
                     \# Screen           Route                Purpose and
                                                              responsibilities
  --------------------- ---------------- -------------------- ------------------------
                     01 Splash Screen    `/splash`            Displays application
                                                              branding while
                                                              initializing the app and
                                                              checking the user's
                                                              authentication/session
                                                              state.

                     02 Onboarding       `/onboarding`        Introduces the platform
                        Screen                                and explains how
                                                              providers can list
                                                              chargers, manage
                                                              bookings, and make
                                                              charging facilities
                                                              available.

                     03 Login Screen     `/login`             Allows an existing
                                                              provider to sign in
                                                              using their registered
                                                              credentials. Includes
                                                              navigation to
                                                              registration and
                                                              password recovery.

                     04 Registration     `/register`          Collects the information
                        Screen                                required to create a
                                                              provider account.

                     05 Email            `/verify-email`      Allows a newly
                        Verification                          registered provider to
                        Screen                                verify their email using
                                                              the verification code or
                                                              OTP flow supported by
                                                              Cognito.

                     06 Forgot Password  `/forgot-password`   Starts the account
                        Screen                                password-recovery
                                                              process.

                     07 Reset Password   `/reset-password`    Allows the provider to
                        Screen                                set a new password after
                                                              completing the required
                                                              recovery verification.

                     08 Provider Account `/provider/setup`    Collects or completes
                        Setup Screen                          provider profile
                                                              information required
                                                              before accessing the
                                                              provider workspace.
  ------------------------------------------------------------------------------------

### 2. Dashboard

  ---------------------------------------------------------------------------------
                     \# Screen           Route                   Purpose and
                                                                 responsibilities
  --------------------- ---------------- ----------------------- ------------------
                     09 Provider         `/provider/dashboard`   Main overview for
                        Dashboard                                the provider.
                                                                 Displays charging
                                                                 station totals,
                                                                 active bookings,
                                                                 session summaries,
                                                                 earnings
                                                                 information where
                                                                 supported, recent
                                                                 bookings, station
                                                                 availability, and
                                                                 quick actions.

  ---------------------------------------------------------------------------------

### 3. Charging station management

  -----------------------------------------------------------------------------------------
                     \# Screen           Route                       Purpose and
                                                                     responsibilities
  --------------------- ---------------- --------------------------- ----------------------
                     10 My Stations      `/provider/stations`        Lists the provider's
                                                                     charging stations and
                                                                     their current
                                                                     availability/status.
                                                                     Provides access to
                                                                     station creation and
                                                                     station details.

                     11 Station Details  `/provider/stations/:id`    Displays an individual
                                                                     station's information,
                                                                     location, charger
                                                                     specifications,
                                                                     pricing, availability,
                                                                     and management
                                                                     actions.

                     12 Add / Edit       `/provider/stations/form`   Form for creating or
                        Station                                      updating a charging
                                                                     station. Includes
                                                                     station name,
                                                                     description,
                                                                     address/location,
                                                                     charger type,
                                                                     connector
                                                                     compatibility, power
                                                                     capacity, pricing,
                                                                     operating hours,
                                                                     availability, and
                                                                     station photographs as
                                                                     supported by the
                                                                     backend.
  -----------------------------------------------------------------------------------------

### 4. Booking management

  ------------------------------------------------------------------------------------
                     \# Screen           Route                      Purpose and
                                                                    responsibilities
  --------------------- ---------------- -------------------------- ------------------
                     13 Bookings         `/provider/bookings`       Displays bookings
                                                                    associated with
                                                                    the provider's
                                                                    charging stations.
                                                                    Organizes bookings
                                                                    by relevant
                                                                    statuses such as
                                                                    upcoming, active,
                                                                    completed, and
                                                                    cancelled,
                                                                    according to
                                                                    backend
                                                                    capabilities.

                     14 Booking Details  `/provider/bookings/:id`   Displays details
                                                                    for a selected
                                                                    booking, such as
                                                                    customer, vehicle,
                                                                    station, scheduled
                                                                    time, and booking
                                                                    status. Shows only
                                                                    actions supported
                                                                    by the backend and
                                                                    booking lifecycle.
  ------------------------------------------------------------------------------------

### 5. Charging sessions

  ------------------------------------------------------------------------------------
                     \# Screen           Route                      Purpose and
                                                                    responsibilities
  --------------------- ---------------- -------------------------- ------------------
                     15 Charging         `/provider/sessions`       Displays charging
                        Sessions                                    session records
                                                                    and their
                                                                    statuses.

                     16 Session Details  `/provider/sessions/:id`   Displays an
                                                                    individual
                                                                    session's
                                                                    available details,
                                                                    such as energy
                                                                    delivered,
                                                                    duration, charging
                                                                    cost, station, and
                                                                    session status.
  ------------------------------------------------------------------------------------

### 6. Provider account

  --------------------------------------------------------------------------------
                     \# Screen           Route                  Purpose and
                                                                responsibilities
  --------------------- ---------------- ---------------------- ------------------
                     17 Profile          `/provider/profile`    Displays provider
                                                                account
                                                                information and
                                                                provides access to
                                                                profile-related
                                                                actions.

                     18 Settings         `/provider/settings`   Contains account
                                                                preferences and
                                                                supported settings
                                                                such as
                                                                notifications,
                                                                security, support,
                                                                and logout.
  --------------------------------------------------------------------------------

> **Implementation note:** This is the planned screen inventory and
> route contract. The exact fields, status values, and available actions
> must be confirmed against the existing Spring Boot APIs before backend
> integration. The UI must not imply that an operation is supported if
> the backend does not provide it.

------------------------------------------------------------------------

## Navigation structure

The authenticated provider workspace will use a bottom navigation bar
with four primary destinations:

  Navigation item   Destination             Purpose
  ----------------- ----------------------- -------------------------------------
  Home              `/provider/dashboard`   Provider overview and quick actions
  Stations          `/provider/stations`    Manage charging stations
  Bookings          `/provider/bookings`    View and manage reservations
  Profile           `/provider/profile`     Provider account and settings

Charging Sessions will be accessible through the dashboard and relevant
booking/station flows, with a dedicated sessions list and details route.
Settings will be accessible from the Profile area.

Authentication, onboarding, verification, and account setup screens are
outside the authenticated bottom-navigation shell.

### Route parameter conventions

Routes containing `:id` use a dynamic path parameter:

-   `/provider/stations/:id` --- `id` identifies the selected charging
    station.
-   `/provider/bookings/:id` --- `id` identifies the selected booking.
-   `/provider/sessions/:id` --- `id` identifies the selected charging
    session.

The Add/Edit Station route may later be extended with an optional
station identifier or query parameter to distinguish create and edit
modes. The route should be finalized when the screen and navigation
behavior are implemented.

------------------------------------------------------------------------

## Flutter source folder structure

The application uses a feature-oriented structure. Each feature owns its
screens and feature-specific widgets. Cross-feature components and
infrastructure remain in shared/core folders.

``` text
lib/
├── main.dart
│
├── app/
│   ├── app.dart
│   └── router.dart
│
├── core/
│   ├── config/
│   │   └── app_config.dart
│   ├── constants/
│   │   └── app_constants.dart
│   ├── network/
│   │   └── dio_client.dart
│   ├── storage/
│   │   └── secure_storage_service.dart
│   ├── theme/
│   │   ├── app_theme.dart
│   │   ├── app_colors.dart
│   │   └── app_text_styles.dart
│   └── utils/
│       └── validators.dart
│
├── features/
│   ├── splash/
│   │   └── presentation/
│   │       └── screens/
│   │           └── splash_screen.dart
│   │
│   ├── onboarding/
│   │   └── presentation/
│   │       └── screens/
│   │           └── onboarding_screen.dart
│   │
│   ├── auth/
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── login_screen.dart
│   │       │   ├── register_screen.dart
│   │       │   ├── verify_email_screen.dart
│   │       │   ├── forgot_password_screen.dart
│   │       │   └── reset_password_screen.dart
│   │       └── widgets/
│   │           ├── auth_header.dart
│   │           ├── auth_text_field.dart
│   │           └── social_auth_button.dart
│   │
│   ├── account_setup/
│   │   └── presentation/
│   │       └── screens/
│   │           └── provider_setup_screen.dart
│   │
│   ├── dashboard/
│   │   └── presentation/
│   │       ├── screens/
│   │       │   └── dashboard_screen.dart
│   │       └── widgets/
│   │           ├── dashboard_header.dart
│   │           ├── statistics_card.dart
│   │           ├── earnings_card.dart
│   │           ├── recent_booking_card.dart
│   │           └── quick_action_card.dart
│   │
│   ├── stations/
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── stations_screen.dart
│   │       │   ├── station_details_screen.dart
│   │       │   └── station_form_screen.dart
│   │       └── widgets/
│   │           ├── station_card.dart
│   │           ├── charger_type_selector.dart
│   │           ├── connector_selector.dart
│   │           ├── availability_selector.dart
│   │           └── station_image_picker.dart
│   │
│   ├── bookings/
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── bookings_screen.dart
│   │       │   └── booking_details_screen.dart
│   │       └── widgets/
│   │           ├── booking_card.dart
│   │           └── booking_status_badge.dart
│   │
│   ├── sessions/
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── sessions_screen.dart
│   │       │   └── session_details_screen.dart
│   │       └── widgets/
│   │           └── session_card.dart
│   │
│   └── profile/
│       └── presentation/
│           ├── screens/
│           │   ├── profile_screen.dart
│           │   └── settings_screen.dart
│           └── widgets/
│               └── profile_header.dart
│
└── shared/
    ├── providers/
    │   └── app_providers.dart
    └── widgets/
        ├── app_button.dart
        ├── app_text_field.dart
        ├── app_loader.dart
        ├── app_error_widget.dart
        ├── app_empty_state.dart
        └── provider_bottom_navigation.dart
```

### Folder responsibilities

  -----------------------------------------------------------------------
  Folder                              Responsibility
  ----------------------------------- -----------------------------------
  `app/`                              Root application widget and
                                      centralized route configuration

  `core/config/`                      Environment-specific application
                                      configuration

  `core/constants/`                   App-wide constants

  `core/network/`                     Dio client and networking
                                      infrastructure

  `core/storage/`                     Secure local storage

  `core/theme/`                       Centralized colors, typography, and
                                      theme definitions

  `core/utils/`                       Shared utility functions such as
                                      input validators

  `features/`                         Feature-specific screens and
                                      widgets

  `shared/providers/`                 Shared Riverpod providers and
                                      dependency wiring

  `shared/widgets/`                   Reusable UI components used across
                                      multiple features
  -----------------------------------------------------------------------

### Architecture growth

The initial structure focuses on presentation so that screens can be
generated and reviewed in Stitch before implementation.

As backend integration begins, features that need data access can be
expanded into layers such as:

``` text
features/stations/
├── data/
│   ├── models/
│   ├── repositories/
│   └── datasources/
├── domain/
│   └── entities/
└── presentation/
    ├── screens/
    ├── widgets/
    └── providers/
```

The same pattern can be introduced for bookings, sessions,
authentication, and other features when justified. We will avoid
creating empty layers that do not yet have a purpose.

------------------------------------------------------------------------

## UI design workflow --- Google Stitch

All 18 screens will be designed in Stitch before Flutter screen
implementation begins.

### Design batches

  -----------------------------------------------------------------------
  Batch                   Screens                 Design focus
  ----------------------- ----------------------- -----------------------
  1                       Splash, onboarding,     Branding and
                          login, registration     authentication visual
                                                  language

  2                       Email verification,     Forms and account flows
                          forgot password, reset  
                          password, provider      
                          setup                   

  3                       Provider dashboard      Information hierarchy,
                                                  metrics, quick actions

  4                       My Stations, Station    Charger management and
                          Details, Add/Edit       forms
                          Station                 

  5                       Bookings, Booking       Reservation management
                          Details                 

  6                       Charging Sessions,      Session history and
                          Session Details         metrics

  7                       Profile, Settings       Account management
  -----------------------------------------------------------------------

### Design consistency requirements

All screens should share:

-   A consistent color palette and typography system.
-   Consistent spacing, corner radii, borders, and shadows.
-   Reusable button, input, card, and status-badge styles.
-   Consistent loading, empty, error, and success states.
-   Consistent iconography and navigation behavior.
-   Mobile-first layouts that work on the target Android devices.

The final colors, typography, components, and spacing tokens will be
documented after the visual direction is approved in Stitch.

### Stitch-to-Flutter workflow

1.  Establish the global visual direction and design system.
2.  Generate the first screen batch in Stitch.
3.  Review and refine each screen.
4.  Reuse the approved visual patterns in subsequent screens.
5.  Finalize the full screen inventory and navigation.
6.  Implement the approved designs in Flutter during Phase 2.
7.  Connect screens to repositories and backend APIs during Phase 3.

------------------------------------------------------------------------

## Development phases

The Charging Provider app will follow five phases. All five phases will
be completed before starting the Vehicle User app.

  -----------------------------------------------------------------------
  Phase                   Name                    Scope
  ----------------------- ----------------------- -----------------------
  Phase 1                 Project Structure &     Flutter setup,
                          Environment Setup       dependencies, Android
                                                  identity, environment
                                                  configuration, routing,
                                                  Riverpod, networking
                                                  foundation, clean
                                                  build, and Git
                                                  integration

  Phase 2                 UI & Screens            Stitch design
                                                  finalization, Flutter
                                                  screen implementation,
                                                  reusable widgets,
                                                  navigation, and UI
                                                  states

  Phase 3                 Backend Integration     Cognito authentication,
                                                  API repositories,
                                                  models, provider data,
                                                  station management,
                                                  bookings, sessions, and
                                                  profile integration

  Phase 4                 Local Testing           Test flows and API
                                                  behavior in the local
                                                  development environment

  Phase 5                 Production Backend      Validate the app
                          Testing                 against the deployed
                                                  Spring Boot backend and
                                                  AWS infrastructure
  -----------------------------------------------------------------------

### Current project status

-   [x] Separate `charging_provider` Flutter project created.
-   [x] Separate `vehicle_user` Flutter project created.
-   [x] Core Flutter dependencies added to Charging Provider.
-   [x] Android application identity and app label configured.
-   [x] Initial Riverpod, GoRouter, Dio, and secure storage foundations
    created.
-   [x] Environment configuration files created.
-   [ ] Final clean build and GitHub integration verification.
-   [ ] Stitch designs finalized.
-   [ ] Phase 2 --- UI and screen implementation.
-   [ ] Phase 3 --- Backend integration.
-   [ ] Phase 4 --- Local testing.
-   [ ] Phase 5 --- Production backend testing.

------------------------------------------------------------------------

## Important implementation principles

1.  **Keep the two mobile apps separate.** Charging Provider and Vehicle
    User have distinct application identities, navigation, and user
    experiences.
2.  **Keep the existing backend.** Both mobile apps will use the
    existing Spring Boot backend unless a specific backend change is
    required.
3.  **Enforce authorization on the backend.** Hiding a screen in Flutter
    is not a security boundary. Spring Security must validate the
    authenticated user and provider role for protected operations.
4.  **Do not invent API behavior in the UI.** Confirm endpoint
    contracts, fields, status values, and supported actions before
    connecting screens.
5.  **Keep configuration and secrets safe.** Never commit passwords,
    access tokens, database credentials, or private keys. Mobile client
    configuration must not contain confidential secrets.
6.  **Build reusable components thoughtfully.** Shared widgets should be
    genuinely reusable; avoid overengineering.
7.  **Design first, implement second.** Stitch designs should be
    reviewed and approved before their Flutter implementation.
