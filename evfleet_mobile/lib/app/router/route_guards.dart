import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import 'route_names.dart';

/// Authentication-based route guards.
///
/// The router re-evaluates these whenever the [AuthState] changes (see
/// `appRouterProvider`'s `refreshListenable`), so sign-in/sign-out move the
/// user to the right group automatically.
abstract final class RouteGuards {
  /// Paths that are only reachable while signed out.
  static const Set<String> _authOnly = {
    RoutePaths.signIn,
    RoutePaths.signUp,
    RoutePaths.verifyEmail,
    RoutePaths.forgotPassword,
    RoutePaths.resetPassword,
  };

  /// Paths reachable regardless of session state.
  static const Set<String> _public = {
    RoutePaths.splash,
    RoutePaths.onboarding,
    RoutePaths.welcome,
    RoutePaths.notFound,
  };

  static String? redirect(AuthState auth, GoRouterState state) {
    final location = state.matchedLocation;

    // Never interrupt the splash screen while the session is restoring.
    if (auth.status == AuthStatus.restoring) {
      return location == RoutePaths.splash ? null : RoutePaths.splash;
    }

    final isPublic = _public.contains(location);
    final isAuthOnly = _authOnly.contains(location);

    if (auth.isAuthenticated) {
      // Authenticated users have no business on the sign-in/up screens.
      if (isAuthOnly) return RoutePaths.home;
      return null;
    }

    // Signed out: keep public/auth routes, everything else → welcome.
    if (isPublic || isAuthOnly) return null;
    return RoutePaths.welcome;
  }
}
