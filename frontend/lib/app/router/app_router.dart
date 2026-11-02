import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/auth/presentation/screens/sign_up_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/bookings/presentation/screens/booking_confirmation_screen.dart';
import '../../features/bookings/presentation/screens/booking_details_screen.dart';
import '../../features/bookings/presentation/screens/booking_screen.dart';
import '../../features/bookings/presentation/screens/my_bookings_screen.dart';
import '../../features/charging_sessions/presentation/screens/charging_history_screen.dart';
import '../../features/charging_sessions/presentation/screens/session_details_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/onboarding/presentation/screens/splash_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/settings_screen.dart';
import '../../features/station_management/presentation/screens/add_station_screen.dart';
import '../../features/station_management/presentation/screens/edit_station_screen.dart';
import '../../features/station_management/presentation/screens/my_stations_screen.dart';
import '../../features/station_management/presentation/screens/station_availability_screen.dart';
import '../../features/station_management/presentation/screens/station_bookings_screen.dart';
import '../../features/stations/presentation/screens/explore_screen.dart';
import '../../features/stations/presentation/screens/station_details_screen.dart';
import '../../features/stations/presentation/screens/station_filters_screen.dart';
import '../../features/stations/presentation/screens/station_map_screen.dart';
import '../../features/vehicles/presentation/screens/add_vehicle_screen.dart';
import '../../features/vehicles/presentation/screens/edit_vehicle_screen.dart';
import '../../features/vehicles/presentation/screens/my_vehicles_screen.dart';
import '../app_shell.dart';
import 'route_guards.dart';
import 'route_names.dart';

/// The application router.
///
/// Auth-dependent redirection lives in [RouteGuards]; this file only wires
/// paths to screens. The router is rebuilt whenever the session changes so a
/// sign-in or sign-out moves the user between the auth group and the app.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authListenable = ValueNotifier<AuthState>(ref.read(authProvider));

  ref.listen<AuthState>(authProvider, (_, next) {
    authListenable.value = next;
  });
  ref.onDispose(authListenable.dispose);

  return GoRouter(
    initialLocation: RoutePaths.splash,
    debugLogDiagnostics: false,
    refreshListenable: authListenable,
    redirect: (context, state) =>
        RouteGuards.redirect(authListenable.value, state),
    routes: [
      // --- Onboarding & authentication ------------------------------------
      GoRoute(
        path: RoutePaths.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: RoutePaths.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: RoutePaths.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: RoutePaths.signUp,
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: RoutePaths.verifyEmail,
        builder: (context, state) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: RoutePaths.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: RoutePaths.resetPassword,
        builder: (context, state) => const ResetPasswordScreen(),
      ),

      // --- Main shell ------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.explore,
                builder: (context, state) => const ExploreScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.bookings,
                builder: (context, state) => const MyBookingsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // --- Station discovery ------------------------------------------------
      GoRoute(
        path: RoutePaths.stationMap,
        builder: (context, state) => const StationMapScreen(),
      ),
      GoRoute(
        path: RoutePaths.stationDetails,
        builder: (context, state) =>
            StationDetailsScreen(stationId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: RoutePaths.stationFilters,
        builder: (context, state) => const StationFiltersScreen(),
      ),

      // --- Booking flow -----------------------------------------------------
      GoRoute(
        path: RoutePaths.createBooking,
        builder: (context, state) =>
            BookingScreen(stationId: state.pathParameters['stationId'] ?? ''),
      ),
      GoRoute(
        path: RoutePaths.bookingDetails,
        builder: (context, state) =>
            BookingDetailsScreen(bookingId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: RoutePaths.bookingConfirmation,
        builder: (context, state) => BookingConfirmationScreen(
          bookingId: state.extra is String
              ? state.extra! as String
              : state.uri.queryParameters['id'] ?? '',
        ),
      ),

      // --- Vehicles ----------------------------------------------------------
      GoRoute(
        path: RoutePaths.vehicles,
        builder: (context, state) => const MyVehiclesScreen(),
      ),
      GoRoute(
        path: RoutePaths.addVehicle,
        builder: (context, state) => const AddVehicleScreen(),
      ),
      GoRoute(
        path: RoutePaths.editVehicle,
        builder: (context, state) =>
            EditVehicleScreen(vehicleId: state.pathParameters['id'] ?? ''),
      ),

      // --- Charging history --------------------------------------------------
      GoRoute(
        path: RoutePaths.chargingHistory,
        builder: (context, state) => const ChargingHistoryScreen(),
      ),
      GoRoute(
        path: RoutePaths.sessionDetails,
        builder: (context, state) =>
            SessionDetailsScreen(sessionId: state.pathParameters['id'] ?? ''),
      ),

      // --- Station owner management -----------------------------------------
      GoRoute(
        path: RoutePaths.myStations,
        builder: (context, state) => const MyStationsScreen(),
      ),
      GoRoute(
        path: RoutePaths.addStation,
        builder: (context, state) => const AddStationScreen(),
      ),
      GoRoute(
        path: RoutePaths.editStation,
        builder: (context, state) =>
            EditStationScreen(stationId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: RoutePaths.stationAvailability,
        builder: (context, state) => StationAvailabilityScreen(
          stationId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: RoutePaths.stationBookings,
        builder: (context, state) =>
            StationBookingsScreen(stationId: state.pathParameters['id'] ?? ''),
      ),

      // --- Profile, settings, notifications ----------------------------------
      GoRoute(
        path: RoutePaths.editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),

      // --- Fallback ------------------------------------------------------------
      GoRoute(
        path: RoutePaths.notFound,
        builder: (context, state) => const _NotFoundScreen(),
      ),
    ],
    errorBuilder: (context, state) => const _NotFoundScreen(),
  );
});

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_off_outlined, size: 48),
              const SizedBox(height: 12),
              const Text('This screen does not exist.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(RoutePaths.home),
                child: const Text('Back to home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
