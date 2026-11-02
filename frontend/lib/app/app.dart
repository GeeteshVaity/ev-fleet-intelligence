import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../core/config/missing_config_screen.dart';
import '../core/network/api_interceptors.dart';
import '../core/network/backend_api_service.dart';
import '../core/constants/api_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/errors/error_handler.dart';
import '../core/utils/location_service.dart';
import '../core/widgets/app_empty_view.dart';
import '../core/widgets/app_error_view.dart';
import '../features/auth/data/cognito_auth_service.dart';
import '../features/auth/domain/auth_user.dart' as domain;
import '../shared/widgets/async_value_view.dart';

class AppColors {
  static const forest = Color(0xFF12372A);
  static const emerald = Color(0xFF1D7A55);
  static const lime = Color(0xFFC8E86B);
  static const surface = Color(0xFFF5F7F5);
  static const ink = Color(0xFF1D2B25);
  static const muted = Color(0xFF718078);
}

/// Radius (km) used for the server-side nearby search. Five kilometres is a
/// walkable/short-drive default; the options are capped at the client maximum
/// accepted by [BackendApiService.fetchNearbyStations].
class SearchRadiusNotifier extends Notifier<double> {
  @override
  double build() => 5;

  void select(double km) => state = km;
}

final searchRadiusProvider = NotifierProvider<SearchRadiusNotifier, double>(
  SearchRadiusNotifier.new,
);

/// Live stations, each decorated with its real availability window count.
///
/// With a device location the backend performs the radius query
/// (`GET /api/stations/nearby`): it validates the coordinates, excludes
/// inactive stations and returns only stations in range, sorted by distance.
/// Without a location the public catalogue (`GET /api/stations`) is shown and
/// distances stay blank. Sample data is returned only when the build explicitly
/// opts in with `--dart-define=DEMO_MODE=true`; a failed request produces an
/// error state, never silent sample data.
final stationsProvider = FutureProvider<List<Station>>((ref) async {
  if (ApiConstants.isMockBackend) return demoStations;
  final api = ref.watch(backendApiServiceProvider);
  final origin = _lastKnownLocation;
  final radiusKm = ref.watch(searchRadiusProvider);
  final rows = origin == null
      ? await api.fetchStations()
      : await api.fetchNearbyStations(
          latitude: origin.$1,
          longitude: origin.$2,
          radiusKm: radiusKm,
        );
  return Future.wait(
    rows.whereType<Map<String, dynamic>>().map((row) async {
      final station = _stationFromJson(row);
      final numericId = int.tryParse(station.id);
      if (numericId == null) return station;
      try {
        final windows = await api.fetchAvailability(numericId);
        return station.copyWith(
          available: windows
              .whereType<Map<String, dynamic>>()
              .where((window) => window['status'] == 'AVAILABLE')
              .length,
        );
      } catch (_) {
        // Availability is extra detail; the station itself still renders.
        return station;
      }
    }),
  );
});

/// Vehicles owned by the signed-in user (`GET /api/vehicles`).
final vehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  if (ApiConstants.isMockBackend) return demoVehicles;
  final rows = await ref.watch(backendApiServiceProvider).fetchVehicles();
  return rows.whereType<Map<String, dynamic>>().map(_vehicleFromJson).toList();
});

/// Bookings for the signed-in user (`GET /api/bookings`).
final bookingsProvider = FutureProvider<List<Booking>>((ref) async {
  if (ApiConstants.isMockBackend) return demoBookings;
  final rows = await ref.watch(backendApiServiceProvider).fetchBookings();
  return rows.whereType<Map<String, dynamic>>().map(_bookingFromJson).toList();
});

/// Local profile from `GET /api/users/me`; null when it does not exist yet.
final profileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  if (ApiConstants.isMockBackend) return null;
  return ref.watch(backendApiServiceProvider).fetchMyProfile();
});

/// Incoming booking requests for one station the signed-in provider owns
/// (`GET /api/stations/{id}/bookings`).
final stationBookingsProvider = FutureProvider.family<List<Booking>, String>((
  ref,
  stationKey,
) async {
  if (ApiConstants.isMockBackend) return demoBookings;
  final stationId = int.tryParse(stationKey);
  if (stationId == null) return const [];
  final rows = await ref
      .watch(backendApiServiceProvider)
      .fetchStationBookings(stationId);
  return rows.whereType<Map<String, dynamic>>().map(_bookingFromJson).toList();
});

/// Stations owned by the signed-in provider (`GET /api/stations/mine`).
final myStationsProvider = FutureProvider<List<Station>>((ref) async {
  if (ApiConstants.isMockBackend) return demoStations;
  final rows = await ref.watch(backendApiServiceProvider).fetchMyStations();
  return rows.whereType<Map<String, dynamic>>().map(_stationFromJson).toList();
});

/// Published charging windows for one station
/// (`GET /api/stations/{id}/availability`).
final availabilityProvider =
    FutureProvider.family<List<AvailabilityWindow>, String>((
      ref,
      stationId,
    ) async {
      if (ApiConstants.isMockBackend) {
        final now = DateTime.now();
        return [
          for (var day = 1; day <= 3; day++)
            AvailabilityWindow(
              id: day,
              start: DateTime(now.year, now.month, now.day + day, 8),
              end: DateTime(now.year, now.month, now.day + day, 20),
              status: 'AVAILABLE',
            ),
        ];
      }
      final id = int.tryParse(stationId);
      if (id == null) {
        throw const ValidationException('Invalid station id.');
      }
      final rows = await ref
          .watch(backendApiServiceProvider)
          .fetchAvailability(id);
      return rows
          .whereType<Map<String, dynamic>>()
          .map(_windowFromJson)
          .toList();
    });

enum UserRole { vehicleOwner, chargerProvider }

extension UserRoleValues on UserRole {
  String get wireValue =>
      this == UserRole.vehicleOwner ? 'VEHICLE_OWNER' : 'CHARGER_PROVIDER';
}

class EvFleetApp extends ConsumerStatefulWidget {
  const EvFleetApp({super.key});

  @override
  ConsumerState<EvFleetApp> createState() => _EvFleetAppState();
}

class _EvFleetAppState extends ConsumerState<EvFleetApp> {
  final _auth = CognitoAuthService();
  UserRole? _role;
  bool _onboardingComplete = false;
  bool _signedIn = false;
  bool _ready = false;

  /// Set once the developer dismisses the missing-configuration screen.
  /// Configuration is validated at startup and never silently skipped.
  bool _configAcknowledged = false;

  /// Created once and reused. Rebuilding the router on every `setState`
  /// resets navigation to [GoRouter.initialLocation], which silently dropped
  /// users back to the sign-in screen whenever any app state changed.
  GoRouter? _router;

  /// Credentials from the registration that is waiting for e-mail verification.
  /// The password is held in memory only - never in prefs or secure storage -
  /// so verification can sign the user in directly. If the process restarts,
  /// verification falls back to the login screen instead of guessing.
  String? _pendingEmail;
  String? _pendingPassword;

  @override
  void initState() {
    super.initState();
    // Any API call that comes back 401 ends the local session.
    SessionEvents.onUnauthorized = _handleSessionExpired;
    // Report missing public configuration once, without tokens or secrets.
    debugPrint('[config] ${AppConfig.summary}');
    _restoreOnboarding();
  }

  @override
  void dispose() {
    if (SessionEvents.onUnauthorized == _handleSessionExpired) {
      SessionEvents.onUnauthorized = null;
    }
    super.dispose();
  }

  Future<void> _restoreOnboarding() async {
    try {
      await _restoreOnboardingImpl().timeout(const Duration(seconds: 20));
    } catch (_) {
      // Startup could not restore a session in time (broken platform channel,
      // a hung plugin, or an unexpected storage error). Never strand the user
      // on a dead error screen: fall back to a clean signed-out state so the
      // login screen loads and the app stays usable. Nothing sensitive is
      // logged and no stack trace is shown.
      if (!mounted) return;
      setState(() {
        _signedIn = false;
        _role = null;
        _onboardingComplete = false;
        _ready = true;
      });
    }
  }

  Future<void> _restoreOnboardingImpl() async {
    final prefs = await SharedPreferences.getInstance();
    var value = prefs.getString('onboarding.role');
    if (!mounted) return;
    var signedIn = prefs.getBool('session.signed_in') ?? false;
    var onboardingComplete = prefs.getBool('onboarding.completed') ?? false;

    if (_auth.isConfigured) {
      domain.AuthUser? restored;
      try {
        restored = await _auth.restoreSession();
        signedIn = restored != null;
      } catch (_) {
        restored = null;
        signedIn = false;
      }

      if (signedIn && ApiConstants.isBackendConfigured) {
        // Cognito owns the session; the backend owns role/onboarding state.
        // A backend outage must not log the user out, so failures here keep
        // the last known local values instead of clearing the session.
        try {
          final api = ref.read(backendApiServiceProvider);
          var me = await api.fetchAuthMe();

          if (me['profileCreated'] == false && restored != null) {
            // Session exists but the local profile was never created.
            if (value != null) {
              await api.saveProfile(
                fullName: restored.fullName,
                email: restored.email,
                role: value,
              );
              me = await api.fetchAuthMe();
            } else {
              // No role was ever chosen: fall back to the sign-in screen so
              // the user can pick one and the profile gets created there.
              signedIn = false;
            }
          }

          final backendRole = me['role'];
          if (backendRole is String && backendRole.isNotEmpty) {
            value = backendRole;
            await prefs.setString('onboarding.role', backendRole);
          }
          final backendOnboardingCompleted = me['onboardingCompleted'];
          if (backendOnboardingCompleted is bool) {
            onboardingComplete = backendOnboardingCompleted;
            await prefs.setBool('onboarding.completed', onboardingComplete);
          }
        } catch (_) {
          // Offline or API error — keep the local copy of the profile state.
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _role = value == 'CHARGER_PROVIDER'
          ? UserRole.chargerProvider
          : value == 'VEHICLE_OWNER'
          ? UserRole.vehicleOwner
          : null;
      _onboardingComplete = onboardingComplete;
      _signedIn = signedIn;
      _ready = true;
    });
    _loadDeviceLocation();
  }

  /// Best-effort device location so station distances can be computed.
  /// Failure (permission denied, no GPS) leaves distances unset — they are
  /// never fabricated.
  Future<void> _loadDeviceLocation() async {
    if (ApiConstants.isMockBackend) return;
    final result = await const LocationService().getCurrentLocation();
    final location = result.location;
    if (location == null || !mounted) return;
    _lastKnownLocation = (location.latitude, location.longitude);
    ref.invalidate(stationsProvider);
  }

  Future<void> _saveRole(UserRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('onboarding.role', role.wireValue);
    if (!mounted) return;
    _role = role;
  }

  Future<String> _signIn({
    required UserRole? selectedRole,
    required String email,
    required String password,
  }) async {
    String? roleFromBackend;
    bool? onboardingFromBackend;

    if (_auth.isConfigured) {
      final user = await _auth.signIn(email: email, password: password);

      if (ApiConstants.isBackendConfigured) {
        final api = ref.read(backendApiServiceProvider);
        var me = await api.fetchAuthMe();

        // First sign-in for this account: create the local profile once, using
        // the role picked on this screen. Also repair legacy profiles that were
        // created without a role, which the backend now refuses to let create
        // vehicles or stations. An existing role is never changed here: the
        // backend only accepts a role while the stored one is empty.
        final backendRoleMissing =
            me['role'] is! String || (me['role'] as String).isEmpty;
        if (me['profileCreated'] == false || backendRoleMissing) {
          await api.saveProfile(
            fullName: user.fullName,
            email: user.email,
            role: (_role ?? selectedRole ?? UserRole.vehicleOwner).wireValue,
          );
          me = await api.fetchAuthMe();
        }

        roleFromBackend =
            me['role'] is String && (me['role'] as String).isNotEmpty
            ? me['role'] as String
            : null;
        final onboardingCompleted = me['onboardingCompleted'];
        debugPrint('[LOGIN DEBUG] authMe response: $me');
        debugPrint('[LOGIN DEBUG] roleFromBackend: $roleFromBackend');
        debugPrint('[LOGIN DEBUG] onboardingFromBackend: $onboardingFromBackend');
        onboardingFromBackend = onboardingCompleted is bool
            ? onboardingCompleted
            : null;
      }
    } else if (!ApiConstants.isMockBackend) {
      // Never fall back to a local-only "session" in an AWS-connected build.
      throw const NotConfiguredException(
        'Sign-in is unavailable: Cognito is not configured for this build.',
        code: 'cognito_not_configured',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final roleToStore =
        roleFromBackend ??
        (_role == null && selectedRole != null ? selectedRole.wireValue : null);
    if (roleToStore != null) {
      await prefs.setString('onboarding.role', roleToStore);
      _role = roleToStore == 'CHARGER_PROVIDER'
          ? UserRole.chargerProvider
          : roleToStore == 'VEHICLE_OWNER'
          ? UserRole.vehicleOwner
          : _role;
    }
    if (onboardingFromBackend != null) {
      _onboardingComplete = onboardingFromBackend;
      await prefs.setBool('onboarding.completed', onboardingFromBackend);
    }
    await prefs.setBool('session.signed_in', true);
    _signedIn = true;
    debugPrint('[LOGIN DEBUG] signedIn: $_signedIn');
    debugPrint('[LOGIN DEBUG] role: $_role');
    debugPrint('[LOGIN DEBUG] onboardingComplete: $_onboardingComplete');
    debugPrint('[LOGIN DEBUG] destination: ${_onboardingComplete ? _homePath : '/account-setup'}');
    return _onboardingComplete ? _homePath : '/account-setup';
  }

  Future<void> _register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    if (_auth.isConfigured) {
      await _auth.signUp(fullName: fullName, email: email, password: password);
      // Keep the just-created credentials in memory so the verification step
      // can sign in without asking for the password again. Nothing is
      // persisted here (see [_pendingPassword]).
      _pendingEmail = email;
      _pendingPassword = password;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_verification.email', email);
      await prefs.setString('pending_verification.name', fullName);
      return;
    }
    if (!ApiConstants.isMockBackend) {
      // Accounts always come from Cognito in an AWS-connected build; a
      // locally faked account would never be able to call the API.
      throw const NotConfiguredException(
        'Registration is unavailable: Cognito is not configured for this build.',
        code: 'cognito_not_configured',
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await ref
        .read(backendApiServiceProvider)
        .saveProfile(
          fullName: fullName,
          email: email,
          role: (_role ?? UserRole.vehicleOwner).wireValue,
        );
    await prefs.setString('account.full_name', fullName);
    await prefs.setString('account.email', email);
    await prefs.setBool('session.signed_in', true);
    _signedIn = true;
  }

  /// Confirms the Cognito e-mail verification code and continues the flow.
  ///
  /// Cognito requires confirmation before an account can sign in, so this
  /// confirms the code and - when the registration password is still in memory
  /// - signs in and returns the next route (`/account-setup`, or the role's
  /// home when onboarding is already complete). A wrong or expired code throws
  /// a user-safe error and leaves the user on the verification screen.
  Future<String> _verifyEmail(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final email =
        _pendingEmail ?? prefs.getString('pending_verification.email');
    if (email == null || email.isEmpty) {
      throw const ValidationException(
        'No account is waiting for verification. Register again or sign in.',
      );
    }
    await _auth.confirmEmail(email: email, code: code);
    final password = _pendingPassword;
    if (password == null || password.isEmpty) {
      // The password is never persisted, so after an app restart the user
      // signs in once with the credentials they just created.
      return '/login';
    }
    final destination = await _signIn(
      selectedRole: _role,
      email: email,
      password: password,
    );
    _pendingPassword = null;
    return destination;
  }

  Future<void> _signOut() async {
    if (_auth.isConfigured) {
      await _auth.signOut();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('session.signed_in', false);
    _pendingPassword = null;
    _pendingEmail = null;
    _signedIn = false;
  }

  Future<void> _updateProfile({
    required String fullName,
    required String email,
    String? phone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (ApiConstants.isBackendConfigured) {
      await ref
          .read(backendApiServiceProvider)
          .saveProfile(fullName: fullName, email: email, phone: phone);
      ref.invalidate(profileProvider);
    }
    await prefs.setString('account.full_name', fullName);
    await prefs.setString('account.email', email);
    if (phone != null) await prefs.setString('account.phone', phone);
  }

  /// Persists the role-specific setup and returns the route to show next.
  ///
  /// Onboarding counts as complete only when the backend profile says so: the
  /// flag is read back from `GET /api/auth/me` instead of being inferred from a
  /// successful local write. A thrown error keeps the user on the setup screen
  /// so no required step is silently skipped.
  Future<String> _completeOnboarding(SetupData data) async {
    final prefs = await SharedPreferences.getInstance();
    final role = _role ?? UserRole.vehicleOwner;
    if (ApiConstants.isMockBackend) {
      await prefs.setBool('onboarding.completed', true);
      if (mounted) setState(() => _onboardingComplete = true);
      return _homePath;
    }

    final api = ref.read(backendApiServiceProvider);
    if (role == UserRole.vehicleOwner) {
      await api.createVehicle(
        vehicleType: data.vehicleType!,
        model: data.model!,
        brand: data.brand,
        registrationNumber: data.registrationNumber,
        batteryCapacityKwh: data.batteryCapacityKwh,
        connectorType: data.connectorType,
      );
    } else {
      await api.createStation(
        stationName: data.stationName!,
        providerType: data.providerType!,
        accessType: data.accessType!,
        address: data.address!,
        latitude: data.latitude!,
        longitude: data.longitude!,
        connectorType: data.connectorType!,
        powerKw: data.powerKw!,
        pricePerKwh: data.pricePerKwh,
      );
    }

    await api.saveOnboarding(role: role.wireValue, completed: true, step: 1);

    // Confirm with the server that the profile really is complete. A failed
    // read-back is not fatal (the write above already returned success and the
    // next launch re-reads the profile), but an explicit `false` is.
    try {
      final me = await api.fetchAuthMe();
      if (me['onboardingCompleted'] == false) {
        throw const ServerException(
          'The server did not confirm your setup yet. Please try again.',
        );
      }
    } on ServerException {
      rethrow;
    } on AppException {
      // Network hiccup after a successful write: continue.
    }

    await prefs.setBool('onboarding.completed', true);
    if (mounted) setState(() => _onboardingComplete = true);
    return _homePath;
  }

  @override
  Widget build(BuildContext context) {
    if (!_configAcknowledged && !AppConfig.isReady) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.emerald),
        ),
        home: MissingConfigScreen(
          issues: AppConfig.issues,
          onContinue: () => setState(() => _configAcknowledged = true),
          onRetry: () => setState(() {}),
        ),
      );
    }
    if (!_ready) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    final router = _router ??= _createRouter();
    return MaterialApp.router(
      title: 'Voltway',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.surface,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.emerald,
          brightness: Brightness.light,
        ),
        fontFamily: 'Inter',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.black.withValues(alpha: .07)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.emerald, width: 1.5),
          ),
        ),
      ),
      routerConfig: router,
    );
  }

  /// Called by the HTTP layer when the backend answers 401: the Cognito
  /// access token is missing, expired or was revoked, so the local session
  /// must be dropped and the user sent back to sign-in.
  Future<void> _handleSessionExpired() async {
    if (!_signedIn) return;
    try {
      await _auth.signOut();
    } catch (_) {
      // Still clear local state: the token is unusable either way.
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('session.signed_in', false);
    if (!mounted) return;
    setState(() {
      _signedIn = false;
      _onboardingComplete = false;
    });
    _router?.go('/login');
  }

  GoRouter _createRouter() {
    return GoRouter(
      // Launch destination, restored from the persisted session plus the
      // backend profile:
      //   signed out             -> /login
      //   signed in, no role yet -> /login
      //   onboarding incomplete  -> /account-setup
      //   onboarding complete     -> role-specific home
      initialLocation: !_signedIn
          ? '/login'
          : _role == null
          ? '/login'
          : !_onboardingComplete
          ? '/account-setup'
          : _homePath,
      // Reads the live state fields, so redirects always see the current
      // session even though the router instance is cached. Every branch either
      // returns a different destination or null, so no rule can redirect a
      // route to itself and loop.
      redirect: (context, state) {
        final location = state.matchedLocation;
        const publicRoutes = {
          '/login',
          '/register',
          '/role',
          '/verify-email',
        };

        // 1. No session: only the public authentication screens are reachable.
        if (!_signedIn) {
          return publicRoutes.contains(location) ? null : '/login';
        }

        // 2. Session without a profile role: finish that at login, where the
        //    role is collected together with the profile.
        if (_role == null) {
          return publicRoutes.contains(location) ? null : '/login';
        }

        // 3. Authenticated but setup incomplete: account setup is the only
        //    screen, so a restart resumes exactly where the user stopped
        //    instead of dropping them on a dashboard.
        if (!_onboardingComplete) {
          return location == '/account-setup' ? null : '/account-setup';
        }

        // 4. Onboarding complete: login, registration, verification and setup
        //    are behind the user for good.
        if (publicRoutes.contains(location) || location == '/account-setup') {
          return _homePath;
        }

        // 5. Keep each role on its own dashboard.
        if (_role == UserRole.chargerProvider &&
            (location.startsWith('/home') ||
                location.startsWith('/explore') ||
                location.startsWith('/bookings') ||
                location.startsWith('/vehicles') ||
                location.startsWith('/book/'))) {
          return '/provider';
        }
        if (_role == UserRole.vehicleOwner &&
            location.startsWith('/provider')) {
          return '/home';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/role',
          builder: (_, __) => RoleSelectionScreen(
            onContinue: (role) async {
              await _saveRole(role);
            },
          ),
        ),
        GoRoute(
          path: '/account-setup',
          builder: (_, __) => SetupScreen(
            role: _role ?? UserRole.vehicleOwner,
            onComplete: _completeOnboarding,
          ),
        ),
        GoRoute(
          path: '/provider',
          builder: (_, __) => const ProviderDashboardScreen(),
        ),
        GoRoute(
          path: '/provider/stations',
          builder: (_, __) => const ProviderStationsScreen(),
        ),
        GoRoute(
          path: '/provider/bookings',
          builder: (_, __) => const ProviderBookingsScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (_, __) => ShellScreen(index: 0, onSignOut: _signOut),
        ),
        GoRoute(
          path: '/explore',
          builder: (_, __) => ShellScreen(index: 1, onSignOut: _signOut),
        ),
        GoRoute(
          path: '/bookings',
          builder: (_, __) => ShellScreen(index: 2, onSignOut: _signOut),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, __) => ShellScreen(index: 3, onSignOut: _signOut),
        ),
        GoRoute(
          path: '/station/:id',
          builder: (_, state) =>
              StationDetailsScreen(id: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/book/:id',
          builder: (_, state) =>
              BookingScreen(stationId: state.pathParameters['id']!),
        ),
        GoRoute(path: '/vehicles', builder: (_, __) => const VehiclesScreen()),
        GoRoute(
          path: '/profile/edit',
          builder: (_, __) => EditProfileScreen(onSave: _updateProfile),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) =>
              SignInScreen(initialRole: _role, onSignIn: _signIn),
        ),
        GoRoute(
          path: '/register',
          builder: (_, __) => RegisterScreen(onRegister: _register),
        ),
        GoRoute(
          path: '/verify-email',
          builder: (_, state) => VerifyEmailScreen(
            email: state.uri.queryParameters['email'],
            onVerify: _verifyEmail,
          ),
        ),
      ],
      errorBuilder: (_, __) => const NotFoundScreen(),
    );
  }

  String get _homePath =>
      _role == UserRole.chargerProvider ? '/provider' : '/home';
}

class Station {
  const Station({
    required this.id,
    required this.name,
    required this.address,
    required this.distance,
    required this.power,
    required this.connector,
    required this.price,
    required this.provider,
    this.available,
    this.rating,
    this.latitude,
    this.longitude,
    this.stationName,
    this.providerType,
    this.accessType,
    this.powerKw,
    this.pricePerKwh,
    this.active = true,
  });

  /// Backend id (`charging_stations.id`); demo stations use string ids.
  final String id;
  final String name, address, distance, power, connector, price, provider;

  /// Number of AVAILABLE charging windows, or null when unknown.
  final int? available;
  final double? rating;
  final double? latitude;
  final double? longitude;

  // Raw backend fields kept for API writes.
  final String? stationName;
  final String? providerType;
  final String? accessType;
  final double? powerKw;
  final double? pricePerKwh;

  /// Whether the listing is published (`charging_stations.active`). Inactive
  /// stations are hidden from driver search by the backend.
  final bool active;

  Station copyWith({int? available}) => Station(
    id: id,
    name: name,
    address: address,
    distance: distance,
    power: power,
    connector: connector,
    price: price,
    provider: provider,
    available: available ?? this.available,
    rating: rating,
    latitude: latitude,
    longitude: longitude,
    stationName: stationName,
    providerType: providerType,
    accessType: accessType,
    powerKw: powerKw,
    pricePerKwh: pricePerKwh,
    active: active,
  );
}

class Vehicle {
  const Vehicle({
    required this.name,
    required this.details,
    required this.connector,
    required this.battery,
    this.id,
  });

  /// Backend id (`vehicles.id`) — required to create a booking.
  final int? id;
  final String name, details, connector;
  final double battery;
}

class Booking {
  const Booking({
    required this.stationId,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.id,
    this.stationName,
  });

  final int? id;
  final int stationId;
  final String? stationName;
  final DateTime startTime;
  final DateTime endTime;

  /// Raw backend status: PENDING, CONFIRMED, CANCELLED or REJECTED.
  final String status;

  String get label => stationName ?? 'Station #$stationId';
  String get dateLabel => DateFormat('d MMM yyyy').format(startTime.toLocal());
  String get timeLabel => '${_clock(startTime)} - ${_clock(endTime)}';
  String get displayStatus {
    if (status.isEmpty) return status;
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }
}

String _clock(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

/// One row from `charger_availability`.
class AvailabilityWindow {
  const AvailabilityWindow({
    required this.id,
    required this.start,
    required this.end,
    required this.status,
  });
  final int? id;
  final DateTime start;
  final DateTime end;
  final String status;
  bool get isAvailable => status == 'AVAILABLE';
}

AvailabilityWindow _windowFromJson(Map<String, dynamic> json) {
  final id = json['id'];
  final start = DateTime.tryParse(json['startTime']?.toString() ?? '');
  final end = DateTime.tryParse(json['endTime']?.toString() ?? '');
  if (start == null || end == null) {
    throw const FormatException('Availability window is missing times.');
  }
  return AvailabilityWindow(
    id: id is int ? id : int.tryParse('${id ?? ''}'),
    start: start,
    end: end,
    status: (json['status'] as String?) ?? 'AVAILABLE',
  );
}

// --------------------------------------------------------------------------
// Backend JSON → UI models (field names follow the Spring Boot entities)
// --------------------------------------------------------------------------

Station _stationFromJson(Map<String, dynamic> json) {
  final id = json['id'];
  final powerKw = json['powerKw'];
  final pricePerKwh = json['pricePerKwh'];
  final latitude = json['latitude'];
  final longitude = json['longitude'];
  final name = (json['stationName'] as String?)?.trim();
  final providerType = json['providerType'] as String?;

  return Station(
    id: id is int ? '$id' : (id?.toString() ?? ''),
    stationName: name,
    name: (name == null || name.isEmpty) ? 'Unnamed station' : name,
    address: (json['address'] as String?) ?? 'Address not provided',
    distance: _distanceLabel(latitude, longitude),
    power: powerKw is num ? '${_num(powerKw)} kW' : '—',
    connector: (json['connectorType'] as String?) ?? '—',
    price: pricePerKwh is num
        ? '\$${_num(pricePerKwh)} / kWh'
        : 'Price on request',
    provider: providerType == null || providerType.isEmpty
        ? 'Provider'
        : providerType[0].toUpperCase() +
              providerType.substring(1).toLowerCase(),
    providerType: providerType,
    accessType: json['accessType'] as String?,
    powerKw: powerKw is num ? powerKw.toDouble() : null,
    pricePerKwh: pricePerKwh is num ? pricePerKwh.toDouble() : null,
    active: json['active'] is bool ? json['active'] as bool : true,
    latitude: latitude is num ? latitude.toDouble() : null,
    longitude: longitude is num ? longitude.toDouble() : null,
  );
}

String _num(num value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(2);

/// Distances are only shown when the device supplies a location; otherwise
/// the label is neutral instead of a fabricated number.
String _distanceLabel(double? latitude, double? longitude) {
  final location = _lastKnownLocation;
  if (location == null || latitude == null || longitude == null) return '—';
  const earthRadius = 6371.0;
  final dLat = _toRad(latitude - location.$1);
  final dLon = _toRad(longitude - location.$2);
  final a =
      pow(sin(dLat / 2), 2) +
      cos(_toRad(location.$1)) * cos(_toRad(latitude)) * pow(sin(dLon / 2), 2);
  final km = earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a));
  return '${km.toStringAsFixed(1)} km';
}

double _toRad(double degrees) => degrees * pi / 180;

/// Populated by the location service when permission is granted.
(double, double)? _lastKnownLocation;

Vehicle _vehicleFromJson(Map<String, dynamic> json) {
  final id = json['id'];
  final brand = (json['brand'] as String?)?.trim();
  final model = (json['model'] as String?)?.trim();
  final vehicleType = (json['vehicleType'] as String?)?.trim();
  final registration = (json['registrationNumber'] as String?)?.trim();
  final battery = json['batteryCapacityKwh'];

  final name = [
    if (brand != null && brand.isNotEmpty) brand,
    if (model != null && model.isNotEmpty) model,
  ].join(' ');
  final details = [
    if (vehicleType != null && vehicleType.isNotEmpty) vehicleType,
    if (registration != null && registration.isNotEmpty) registration,
  ].join(' • ');

  return Vehicle(
    id: id is int ? id : int.tryParse('${id ?? ''}'),
    name: name.isEmpty ? 'Unnamed vehicle' : name,
    details: details.isEmpty ? 'Details not provided' : details,
    connector: (json['connectorType'] as String?) ?? '—',
    battery: battery is num ? battery.toDouble() : 0,
  );
}

Booking _bookingFromJson(Map<String, dynamic> json) {
  final id = json['id'];
  final stationId = json['stationId'];
  final start = DateTime.tryParse(json['startTime']?.toString() ?? '');
  final end = DateTime.tryParse(json['endTime']?.toString() ?? '');
  if (start == null || end == null || stationId == null) {
    throw const FormatException('Booking is missing required fields.');
  }
  return Booking(
    id: id is int ? id : int.tryParse('${id ?? ''}'),
    stationId: stationId is int ? stationId : int.tryParse('$stationId') ?? 0,
    startTime: start,
    endTime: end,
    status: (json['status'] as String?) ?? 'PENDING',
  );
}

final demoStations = [
  const Station(
    id: 'green-square',
    name: 'Green Square Hub',
    address: '24 Park Avenue, Central',
    distance: '0.8 km',
    power: '150 kW',
    connector: 'CCS2',
    price: '\$0.42 / kWh',
    available: 6,
    provider: 'Public',
    rating: 4.8,
  ),
  const Station(
    id: 'home-charge',
    name: 'HomeCharge by Maya',
    address: '18 River Lane, Westside',
    distance: '1.6 km',
    power: '22 kW',
    connector: 'Type 2',
    price: '\$0.28 / kWh',
    available: 1,
    provider: 'Household',
  ),
  const Station(
    id: 'metro-fast',
    name: 'Metro Fast Charge',
    address: '91 Market Street',
    distance: '2.4 km',
    power: '350 kW',
    connector: 'CCS2',
    price: '\$0.55 / kWh',
    available: 3,
    provider: 'Business',
    rating: 4.6,
  ),
];

final demoVehicles = [
  const Vehicle(
    id: 1,
    name: 'Tesla Model 3',
    details: '2023 • Long Range',
    connector: 'CCS2',
    battery: 75,
  ),
  const Vehicle(
    id: 2,
    name: 'Nissan Leaf',
    details: '2021 • Tekna',
    connector: 'CHAdeMO',
    battery: 40,
  ),
];

final demoBookings = [
  Booking(
    id: 1,
    stationId: 1,
    stationName: 'Green Square Hub',
    startTime: DateTime.now().add(const Duration(days: 1, hours: 9)),
    endTime: DateTime.now().add(const Duration(days: 1, hours: 10)),
    status: 'CONFIRMED',
  ),
  Booking(
    id: 2,
    stationId: 2,
    stationName: 'HomeCharge by Maya',
    startTime: DateTime(2026, 6, 12, 18),
    endTime: DateTime(2026, 6, 12, 19),
    status: 'COMPLETED',
  ),
];

class ShellScreen extends StatefulWidget {
  const ShellScreen({required this.index, required this.onSignOut, super.key});
  final int index;
  final Future<void> Function() onSignOut;
  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  late int selected = widget.index;
  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(),
      ExploreScreen(),
      BookingsScreen(),
      ProfileScreen(onSignOut: widget.onSignOut),
    ];
    return Scaffold(
      body: screens[selected],
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) {
          setState(() => selected = i);
          context.go(['/home', '/explore', '/bookings', '/profile'][i]);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stationsAsync = ref.watch(stationsProvider);
    final profile = ref.watch(profileProvider);
    final stationCount = stationsAsync.value?.length;
    return AppPage(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: [
          Row(
            children: [
              _ProfileAvatar(profile: profile),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greetingFor(profile),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const Text(
                      'Ready for your next charge?',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_none_rounded),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.forest,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Find your next charge',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        stationCount == null
                            ? stationsAsync.hasError
                                  ? 'Station feed unavailable'
                                  : 'Loading stations nearby…'
                            : stationCount == 0
                            ? 'No stations published yet'
                            : '$stationCount station${stationCount == 1 ? '' : 's'} available nearby',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .7),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => context.go('/explore'),
                        icon: const Icon(Icons.bolt),
                        label: const Text('Find a charger'),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.electric_car_rounded,
                  size: 76,
                  color: AppColors.lime,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Quick actions',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () => context.go('/explore'),
                child: const Text('Explore all'),
              ),
            ],
          ),
          Row(
            children: [
              QuickAction(
                icon: Icons.calendar_month,
                label: 'Bookings',
                onTap: () => context.go('/bookings'),
              ),
              QuickAction(
                icon: Icons.directions_car_filled,
                label: 'Vehicles',
                onTap: () => context.push('/vehicles'),
              ),
              QuickAction(
                icon: Icons.add_business,
                label: 'List charger',
                onTap: () => _showMessage(
                  context,
                  'Charger listings are created during account setup for the charger-provider role.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Nearby stations',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._stationPreview(ref, stationsAsync),
          const SizedBox(height: 8),
          const UpcomingCard(),
        ],
      ),
    );
  }
}

/// Loading / error / empty / data states for the home preview list, rendered
/// inline in the page's scroll view (no nested scrollable).
List<Widget> _stationPreview(WidgetRef ref, AsyncValue<List<Station>> value) {
  if (value.isLoading && !value.hasValue) {
    return const [
      Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      ),
    ];
  }
  if (value.hasError && !value.hasValue) {
    return [
      AppErrorView(
        compact: true,
        message: errorMessageOf(value.error!),
        onRetry: () => ref.invalidate(stationsProvider),
      ),
    ];
  }
  final stations = value.value ?? const <Station>[];
  if (stations.isEmpty) {
    return const [
      AppEmptyView(
        compact: true,
        title: 'No stations yet',
        message: 'Charging stations published by providers will appear here.',
      ),
    ];
  }
  return [
    for (final station in stations.take(2))
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: StationCard(station: station),
      ),
  ];
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.profile});
  final AsyncValue<Map<String, dynamic>?> profile;

  @override
  Widget build(BuildContext context) {
    final name = profile.value?['fullName'];
    final initials = (name is String && name.trim().isNotEmpty)
        ? name
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((part) => part[0].toUpperCase())
              .join()
        : null;
    return CircleAvatar(
      radius: 23,
      backgroundColor: AppColors.forest,
      child: initials == null
          ? const Icon(Icons.person_outline, color: Colors.white, size: 22)
          : Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}

/// Personalised greeting built from the signed-in user's real profile.
/// Never invents a name when the profile has not been loaded.
String greetingFor(AsyncValue<Map<String, dynamic>?> profile) {
  final hour = DateTime.now().hour;
  final part = hour < 12
      ? 'Good morning'
      : hour < 17
      ? 'Good afternoon'
      : 'Good evening';
  final name = profile.value?['fullName'];
  if (name is String && name.trim().isNotEmpty) {
    return '$part, ${name.trim().split(RegExp(r'\s+')).first}';
  }
  return part;
}

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});
  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  bool map = false;

  /// Manual "Use current location" state: spinner, resolved coordinates and
  /// any failure notice. Kept local so the control never blocks rendering.
  bool _locating = false;
  (double, double)? _deviceLocation;
  String? _locationNotice;

  /// Material 3 "Use current location" control.
  ///
  /// [LocationService] checks that location services are on, requests the
  /// Android permission declared in AndroidManifest.xml, and resolves the
  /// coordinates. A spinner shows while GPS runs; failures keep the previous
  /// origin and expose a notice with Retry, leaving the search field as the
  /// manual fallback.
  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _locationNotice = null;
    });
    final result = await const LocationService().getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _locating = false;
      switch (result.status) {
        case LocationStatus.granted:
          final loc = result.location;
          if (loc != null) {
            _deviceLocation = (loc.latitude, loc.longitude);
            _lastKnownLocation = _deviceLocation;
          }
          break;
        case LocationStatus.serviceDisabled:
          _locationNotice = 'Turn on location services, then try again.';
          break;
        case LocationStatus.denied:
          _locationNotice =
              'Location permission was denied. You can still search above.';
          break;
        case LocationStatus.deniedForever:
          _locationNotice =
              'Location permission is blocked. Enable it in system settings, '
              'or search above.';
          break;
        case LocationStatus.unavailable:
          _locationNotice = 'Could not get your location. Try again.';
          break;
      }
    });
  }

  Widget _locationBar(BuildContext context) {
    if (_locating) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          height: 48,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final coords = _deviceLocation;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.tonalIcon(
            onPressed: _useCurrentLocation,
            icon: const Icon(Icons.my_location),
            label: Text(
              coords != null ? 'Location updated' : 'Use current location',
            ),
          ),
          if (coords != null) ...[
            const SizedBox(height: 8),
            Text(
              '${coords.$1.toStringAsFixed(5)}, '
              '${coords.$2.toStringAsFixed(5)}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
          if (_locationNotice != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _locationNotice!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _useCurrentLocation,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  /// Radius selector for the server-side nearby query. Only shown once a
  /// device location exists, because without one the search is not a radius
  /// query at all.
  Widget _radiusSelector(BuildContext context) {
    if (_deviceLocation == null) return const SizedBox.shrink();
    final radius = ref.watch(searchRadiusProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Search radius',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final km in const [1.0, 5.0, 10.0, 25.0, 50.0])
                ChoiceChip(
                  label: Text('${km.toInt()} km'),
                  selected: radius == km,
                  onSelected: (_) {
                    ref.read(searchRadiusProvider.notifier).select(km);
                    ref.invalidate(stationsProvider);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  String query = '';
  @override
  Widget build(BuildContext context) {
    final stationsAsync = ref.watch(stationsProvider);
    return AppPage(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Explore stations',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: () => _showMessage(
                    context,
                    'Availability filters are not connected in this build.',
                  ),
                  icon: const Icon(Icons.tune),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              onChanged: (v) => setState(() => query = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by station or area',
              ),
            ),
          ),
          _locationBar(context),
          _radiusSelector(context),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('List'),
                  icon: Icon(Icons.list),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Map'),
                  icon: Icon(Icons.map_outlined),
                ),
              ],
              selected: {map},
              onSelectionChanged: (value) => setState(() => map = value.first),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: map
                ? const DemoMap()
                : AsyncValueView<List<Station>>(
                    value: stationsAsync,
                    loadingLabel: 'Loading stations…',
                    onRetry: () => ref.invalidate(stationsProvider),
                    empty: () => AppEmptyView(
                      compact: true,
                      icon: Icons.search_off,
                      title: _deviceLocation == null
                          ? (query.isEmpty ? 'No stations yet' : 'No matches')
                          : 'Nothing within '
                                '${ref.read(searchRadiusProvider).toInt()} km',
                      message: _deviceLocation == null
                          ? (query.isEmpty
                                ? 'Charging stations published by providers will appear here.'
                                : 'Nothing matches "$query".')
                          : 'No chargers in this radius. Try a larger radius, or '
                                'move the search by updating your location.',
                    ),
                    builder: (all) {
                      final matches = all
                          .where(
                            (s) =>
                                s.name.toLowerCase().contains(
                                  query.toLowerCase(),
                                ) ||
                                s.address.toLowerCase().contains(
                                  query.toLowerCase(),
                                ),
                          )
                          .toList();
                      if (matches.isEmpty) {
                        return AppEmptyView(
                          compact: true,
                          icon: Icons.search_off,
                          title: 'No matches',
                          message: 'Nothing matches "$query".',
                        );
                      }
                      return ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: matches
                            .map(
                              (s) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: StationCard(station: s),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Decorative map used only by the explicit demo build. The AWS-connected
/// build states plainly that a real map is not wired up instead of drawing
/// invented station pins.
class DemoMap extends ConsumerWidget {
  const DemoMap({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ApiConstants.isMockBackend) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFDDE9DF),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: [
            const Center(
              child: Icon(Icons.map, size: 100, color: AppColors.emerald),
            ),
            Positioned(top: 90, left: 60, child: _Pin(label: '6')),
            Positioned(top: 180, right: 55, child: _Pin(label: '3')),
            Positioned(bottom: 100, left: 130, child: _Pin(label: '1')),
            const Positioned(
              bottom: 20,
              left: 20,
              child: Text(
                'Demo station map',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFDDE9DF),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.map_outlined, size: 64, color: AppColors.emerald),
              SizedBox(height: 14),
              Text(
                'Map view is not wired up in this build',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'Switch to List to browse live station data from the API.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: AppColors.forest,
      shape: BoxShape.circle,
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}

class StationCard extends StatelessWidget {
  const StationCard({required this.station, super.key});
  final Station station;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => context.push('/station/${station.id}'),
    borderRadius: BorderRadius.circular(18),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: .06)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.lime.withValues(alpha: .3),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.ev_station, color: AppColors.forest),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      station.address,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (station.distance != '—')
                _Info(icon: Icons.near_me, value: station.distance),
              _Info(icon: Icons.bolt, value: station.power),
              _Info(icon: Icons.power, value: station.connector),
              const Spacer(),
              Text(
                station.available == null
                    ? 'Availability unknown'
                    : station.available == 0
                    ? 'Fully booked'
                    : '${station.available} free',
                style: const TextStyle(
                  color: AppColors.emerald,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              if (station.rating != null) ...[
                const Icon(Icons.star, size: 16, color: Color(0xFFE5A923)),
                const SizedBox(width: 4),
                Text(
                  station.rating!.toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
              ],
              Text(
                station.provider,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const Spacer(),
              Text(
                station.price,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.forest,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.value});
  final IconData icon;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 12),
    child: Row(
      children: [
        Icon(icon, size: 14, color: AppColors.emerald),
        const SizedBox(width: 3),
        Text(
          value,
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    ),
  );
}

class StationDetailsScreen extends ConsumerWidget {
  const StationDetailsScreen({required this.id, super.key});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stationsAsync = ref.watch(stationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Station details')),
      body: AsyncValueView<List<Station>>(
        value: stationsAsync,
        loadingLabel: 'Loading station…',
        onRetry: () => ref.invalidate(stationsProvider),
        builder: (stations) {
          Station? station;
          for (final candidate in stations) {
            if (candidate.id == id) station = candidate;
          }
          if (station == null) {
            // Never fall back to a different, unrelated station.
            return AppEmptyView(
              icon: Icons.location_off_outlined,
              title: 'Station not found',
              message: 'This station is no longer available. It may have been removed or deactivated.',
              actionLabel: 'Back to stations',
              onAction: () => context.go('/explore'),
            );
          }
          final found = station;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                height: 190,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDE9DF),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(
                  child: Icon(
                    Icons.ev_station,
                    size: 80,
                    color: AppColors.emerald,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                found.name,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 17,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      found.address,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              StationCard(station: found),
              const SizedBox(height: 20),
              const Text(
                'About this station',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Listed by a ${found.provider.toLowerCase()} provider with '
                '${found.connector} connectivity at ${found.power}. '
                'Pricing and availability come from the server and are '
                're-checked when you book.',
                style: const TextStyle(color: AppColors.muted, height: 1.5),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.push('/book/${found.id}'),
                icon: const Icon(Icons.calendar_month),
                label: const Text('Book charging slot'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({required this.stationId, super.key});
  final String stationId;
  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  DateTime date = DateTime.now().add(const Duration(days: 1));
  String? vehicleId;
  AvailabilityWindow? window;
  bool _submitting = false;
  String? _submitError;

  @override
  Widget build(BuildContext context) {
    final stationsAsync = ref.watch(stationsProvider);
    final vehiclesAsync = ref.watch(vehiclesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Book a slot')),
      body: AsyncValueView<List<Station>>(
        value: stationsAsync,
        loadingLabel: 'Loading station…',
        onRetry: () => ref.invalidate(stationsProvider),
        builder: (stations) {
          Station? match;
          for (final candidate in stations) {
            if (candidate.id == widget.stationId) match = candidate;
          }
          if (match == null) {
            return AppEmptyView(
              icon: Icons.location_off_outlined,
              title: 'Station not found',
              message: 'This station is no longer available for booking.',
              actionLabel: 'Back to stations',
              onAction: () => context.go('/explore'),
            );
          }
          return AsyncValueView<List<Vehicle>>(
            value: vehiclesAsync,
            loadingLabel: 'Loading your vehicles…',
            onRetry: () => ref.invalidate(vehiclesProvider),
            empty: () => AppEmptyView(
              icon: Icons.directions_car_outlined,
              title: 'No vehicle yet',
              message:
                  'A booking needs a vehicle from your garage. Add one first.',
              actionLabel: 'Add a vehicle',
              onAction: () => context.push('/vehicles'),
            ),
            builder: (vehicles) => _buildForm(context, match!, vehicles),
          );
        },
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    Station station,
    List<Vehicle> vehicles,
  ) {
    final availabilityAsync = ref.watch(availabilityProvider(station.id));
    final windows = availabilityAsync.value ?? const <AvailabilityWindow>[];
    final dayWindows = windows
        .where(
          (w) => w.isAvailable && DateUtils.isSameDay(w.start.toLocal(), date),
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          station.name,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Pick a published availability window. The server confirms the booking.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 26),
        const Text(
          'Choose a vehicle',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: vehicleId,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.directions_car_outlined),
            labelText: 'Vehicle',
          ),
          items: vehicles
              .map(
                (v) => DropdownMenuItem(
                  value: v.id?.toString() ?? v.name,
                  child: Text(v.name),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() {
            vehicleId = value;
            window = null;
          }),
        ),
        const SizedBox(height: 20),
        const Text(
          'Date',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 90)),
              initialDate: date,
            );
            if (picked != null) {
              setState(() {
                date = picked;
                window = null;
              });
            }
          },
          icon: const Icon(Icons.calendar_today),
          label: Align(
            alignment: Alignment.centerLeft,
            child: Text(DateFormat('EEEE, d MMMM').format(date)),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Available windows',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),
        if (availabilityAsync.isLoading && !availabilityAsync.hasValue)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          )
        else if (availabilityAsync.hasError && !availabilityAsync.hasValue)
          AppErrorView(
            compact: true,
            message: errorMessageOf(availabilityAsync.error!),
            onRetry: () => ref.invalidate(availabilityProvider(station.id)),
          )
        else if (dayWindows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No availability published for this date. Try another day.',
              style: TextStyle(color: AppColors.muted),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: dayWindows
                .map(
                  (w) => ChoiceChip(
                    label: Text('${_clock(w.start)} – ${_clock(w.end)}'),
                    selected: window?.id == w.id,
                    onSelected: (_) => setState(() => window = w),
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.lime.withValues(alpha: .23),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.forest),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'The server re-checks connector compatibility, ownership and availability before saving.',
                  style: TextStyle(color: AppColors.forest),
                ),
              ),
            ],
          ),
        ),
        if (_submitError != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _submitError!,
              style: TextStyle(color: Colors.red.shade800),
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: vehicleId == null || window == null || _submitting
              ? null
              : () => _submit(station),
          child: _submitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Request booking'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Creates the booking through the API. Failures are shown verbatim from
  /// the normalised server message; nothing is written locally on failure.
  Future<void> _submit(Station station) async {
    final selectedWindow = window;
    final selectedVehicle = vehicleId;
    final stationId = int.tryParse(station.id);
    final id = int.tryParse(selectedVehicle ?? '');
    if (selectedWindow == null || stationId == null || id == null) return;

    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      await ref
          .read(backendApiServiceProvider)
          .createBooking(
            vehicleId: id,
            stationId: stationId,
            startTime: selectedWindow.start,
            endTime: selectedWindow.end,
          );
      ref.invalidate(bookingsProvider);
      ref.invalidate(availabilityProvider(station.id));
      if (!mounted) return;
      context.go('/bookings');
      _showMessage(context, 'Booking request submitted for confirmation.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = errorMessageOf(error);
      });
    }
  }
}

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(bookingsProvider);
    final stationsAsync = ref.watch(stationsProvider);
    final stationNames = <int, String>{};
    for (final station in stationsAsync.value ?? const <Station>[]) {
      final id = int.tryParse(station.id);
      if (id != null) stationNames[id] = station.name;
    }
    return AppPage(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          const Text(
            'My bookings',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Keep your charging plans in one place',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 22),
          AsyncValueView<List<Booking>>(
            value: bookingsAsync,
            loadingLabel: 'Loading bookings…',
            onRetry: () => ref.invalidate(bookingsProvider),
            empty: () => const AppEmptyView(
              icon: Icons.calendar_month_outlined,
              title: 'No bookings yet',
              message: 'Charging slots you book will appear here.',
            ),
            builder: (bookings) => Column(
              children: [
                for (final booking in bookings)
                  BookingCard(
                    booking: booking,
                    stationName: stationNames[booking.stationId],
                    onCancel: booking.status == 'PENDING'
                        ? () async {
                            final id = booking.id;
                            if (id == null) return;
                            try {
                              await ref
                                  .read(backendApiServiceProvider)
                                  .cancelBooking(id);
                              ref.invalidate(bookingsProvider);
                            } catch (error) {
                              if (context.mounted) {
                                _showMessage(context, errorMessageOf(error));
                              }
                            }
                          }
                        : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BookingCard extends StatelessWidget {
  const BookingCard({
    required this.booking,
    this.stationName,
    this.onCancel,
    super.key,
  });
  final Booking booking;
  final String? stationName;
  final Future<void> Function()? onCancel;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: AppColors.lime.withValues(alpha: .3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.ev_station, color: AppColors.forest),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stationName ?? booking.label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${booking.dateLabel} • ${booking.timeLabel}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            StatusBadge(status: booking.displayStatus),
          ],
        ),
        if (onCancel != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Cancel booking'),
            ),
          ),
        ],
      ],
    ),
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status, super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final active = status == 'Confirmed' || status == 'Pending';
    final failed = status == 'Cancelled' || status == 'Rejected';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color:
            (failed
                    ? Colors.red.shade100
                    : active
                    ? AppColors.lime
                    : Colors.grey.shade200)
                .withValues(alpha: .55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          color: failed
              ? Colors.red.shade800
              : active
              ? AppColors.forest
              : AppColors.muted,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class VehiclesScreen extends ConsumerWidget {
  const VehiclesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehiclesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My vehicles'),
        actions: [
          IconButton(
            tooltip: 'Add vehicle',
            onPressed: () => _showAddVehicleDialog(context, ref),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: AsyncValueView<List<Vehicle>>(
        value: vehiclesAsync,
        loadingLabel: 'Loading your garage…',
        onRetry: () => ref.invalidate(vehiclesProvider),
        empty: () => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Your garage',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            const AppEmptyView(
              icon: Icons.directions_car_outlined,
              title: 'No vehicles yet',
              message: 'Add a vehicle so you can book charging slots for it.',
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _showAddVehicleDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add vehicle'),
            ),
          ],
        ),
        builder: (vehicles) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Your garage',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            ...vehicles.map(
              (v) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.directions_car_filled,
                      color: AppColors.emerald,
                      size: 32,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${v.details} • ${v.battery} kWh',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (v.connector != '—')
                      Chip(
                        label: Text(
                          v.connector,
                          style: const TextStyle(fontSize: 11),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _showAddVehicleDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add vehicle'),
            ),
          ],
        ),
      ),
    );
  }
}

void _showAddVehicleDialog(BuildContext context, WidgetRef ref) {
  showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      child: AddVehicleForm(
        onSubmit: (data) async {
          await ref
              .read(backendApiServiceProvider)
              .createVehicle(
                vehicleType: data.vehicleType,
                model: data.model,
                brand: data.brand,
                registrationNumber: data.registrationNumber,
                batteryCapacityKwh: data.batteryCapacityKwh,
                connectorType: data.connectorType,
              );
          ref.invalidate(vehiclesProvider);
        },
      ),
    ),
  );
}

class VehicleDraft {
  const VehicleDraft({
    required this.vehicleType,
    required this.model,
    this.brand,
    this.registrationNumber,
    this.batteryCapacityKwh,
    this.connectorType,
  });
  final String vehicleType;
  final String model;
  final String? brand;
  final String? registrationNumber;
  final double? batteryCapacityKwh;
  final String? connectorType;
}

/// Creates a vehicle through `POST /api/vehicles`; the backend validates the
/// payload and scopes it to the signed-in owner.
class AddVehicleForm extends StatefulWidget {
  const AddVehicleForm({required this.onSubmit, super.key});
  final Future<void> Function(VehicleDraft data) onSubmit;
  @override
  State<AddVehicleForm> createState() => _AddVehicleFormState();
}

class _AddVehicleFormState extends State<AddVehicleForm> {
  final _formKey = GlobalKey<FormState>();
  final _type = TextEditingController();
  final _model = TextEditingController();
  final _brand = TextEditingController();
  final _registration = TextEditingController();
  final _battery = TextEditingController();
  final _connector = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _type,
      _model,
      _brand,
      _registration,
      _battery,
      _connector,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        VehicleDraft(
          vehicleType: _type.text.trim(),
          model: _model.text.trim(),
          brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
          registrationNumber: _registration.text.trim().isEmpty
              ? null
              : _registration.text.trim(),
          batteryCapacityKwh: _battery.text.trim().isEmpty
              ? null
              : double.parse(_battery.text.trim()),
          connectorType: _connector.text.trim().isEmpty
              ? null
              : _connector.text.trim(),
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorMessageOf(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Form(
      key: _formKey,
      child: ListView(
        shrinkWrap: true,
        children: [
          const Text(
            'Add vehicle',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red.shade800),
              ),
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: _type,
            decoration: const InputDecoration(labelText: 'Vehicle type *'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Vehicle type is required'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _model,
            decoration: const InputDecoration(labelText: 'Model *'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Model is required'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _brand,
            decoration: const InputDecoration(labelText: 'Brand'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _registration,
            decoration: const InputDecoration(labelText: 'Registration number'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _battery,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Battery capacity (kWh)',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              final number = double.tryParse(value.trim());
              return number == null || number <= 0
                  ? 'Battery capacity must be a positive number'
                  : null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _connector,
            decoration: const InputDecoration(labelText: 'Connector type'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save vehicle'),
          ),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    ),
  );
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({required this.onSignOut, super.key});

  final Future<void> Function() onSignOut;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.value;
    final name = profile?['fullName'] is String
        ? profile!['fullName'] as String
        : '';
    final email = profile?['email'] is String
        ? profile!['email'] as String
        : '';
    final phone = profile?['phone'] is String
        ? profile!['phone'] as String
        : '';
    final role = profile?['role'] is String ? profile!['role'] as String : '';
    final initials = name.trim().isEmpty
        ? null
        : name
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((part) => part[0].toUpperCase())
              .join();
    return AppPage(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Profile',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/profile/edit'),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit profile'),
            ),
          ),
          const SizedBox(height: 20),
          if (profileAsync.isLoading && !profileAsync.hasValue)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (profileAsync.hasError && !profileAsync.hasValue)
            AppErrorView(
              compact: true,
              message: errorMessageOf(profileAsync.error!),
              onRetry: () => ref.invalidate(profileProvider),
            )
          else
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.forest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.lime,
                    child: initials == null
                        ? const Icon(
                            Icons.person_outline,
                            color: AppColors.forest,
                          )
                        : Text(
                            initials,
                            style: const TextStyle(
                              color: AppColors.forest,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? 'Name not set' : name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          email.isEmpty ? 'Email not set' : email,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        if (phone.isNotEmpty)
                          Text(
                            phone,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        if (role.isNotEmpty)
                          Text(
                            role == 'CHARGER_PROVIDER'
                                ? 'Charger provider'
                                : 'Vehicle owner',
                            style: const TextStyle(color: AppColors.lime),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          _ProfileItem(
            icon: Icons.directions_car_outlined,
            title: 'My vehicles',
            onTap: () => context.push('/vehicles'),
          ),
          _ProfileItem(
            icon: Icons.notifications_none,
            title: 'Notifications',
            onTap: () => _showMessage(
              context,
              'Notification preferences are not connected yet.',
            ),
          ),
          _ProfileItem(
            icon: Icons.settings_outlined,
            title: 'Settings',
            onTap: () => _showMessage(
              context,
              'Settings are ready for your product configuration.',
            ),
          ),
          _ProfileItem(
            icon: Icons.logout,
            title: 'Sign out',
            onTap: () async {
              await onSignOut();
              if (context.mounted) context.go('/login');
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({required this.onSave, super.key});

  final Future<void> Function({
    required String fullName,
    required String email,
    String? phone,
  })
  onSave;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _name.text = prefs.getString('account.full_name') ?? '';
    _email.text = prefs.getString('account.email') ?? '';
    _phone.text = prefs.getString('account.phone') ?? '';
    setState(() {});
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.onSave(
        fullName: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
      );
      if (mounted) context.pop();
    } catch (error) {
      if (!mounted) return;
      _showMessage(context, 'Could not save profile: $error');
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit profile')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Full name'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Full name is required'
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: (value) => value == null || !value.contains('@')
                ? 'Enter a valid email address'
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone (optional)'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const CircularProgressIndicator()
                : const Text('Save changes'),
          ),
        ],
      ),
    ),
  );
}

class _ProfileItem extends StatelessWidget {
  const _ProfileItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: Icon(icon, color: AppColors.emerald),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right),
    contentPadding: EdgeInsets.zero,
  );
}

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({required this.onContinue, super.key});

  final Future<void> Function(UserRole role) onContinue;

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  UserRole? _selected;
  bool _busy = false;

  Future<void> _continue() async {
    final selected = _selected;
    if (selected == null || _busy) return;
    setState(() => _busy = true);
    await widget.onContinue(selected);
    if (!mounted) return;
    setState(() => _busy = false);
    context.push('/register');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 32),
          const Icon(
            Icons.ev_station_rounded,
            size: 52,
            color: AppColors.emerald,
          ),
          const SizedBox(height: 20),
          const Text(
            'How will you use Voltway?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a primary role to personalize your experience.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 28),
          _RoleCard(
            role: UserRole.vehicleOwner,
            selected: _selected == UserRole.vehicleOwner,
            icon: Icons.electric_car_rounded,
            title: 'Vehicle Owner',
            subtitle: 'Find nearby chargers and book charging slots.',
            onTap: () => setState(() => _selected = UserRole.vehicleOwner),
          ),
          const SizedBox(height: 14),
          _RoleCard(
            role: UserRole.chargerProvider,
            selected: _selected == UserRole.chargerProvider,
            icon: Icons.ev_station_rounded,
            title: 'Charger Provider',
            subtitle: 'List your charger and manage charging requests.',
            onTap: () => setState(() => _selected = UserRole.chargerProvider),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _selected == null || _busy ? null : _continue,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Continue'),
          ),
        ],
      ),
    ),
  );
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final UserRole role;
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: selected ? AppColors.lime.withValues(alpha: .28) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? AppColors.emerald
              : Colors.black.withValues(alpha: .08),
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: selected ? AppColors.emerald : AppColors.surface,
            child: Icon(
              icon,
              color: selected ? Colors.white : AppColors.emerald,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? AppColors.emerald : AppColors.muted,
          ),
        ],
      ),
    ),
  );
}

class SetupData {
  const SetupData({
    this.vehicleType,
    this.model,
    this.brand,
    this.registrationNumber,
    this.batteryCapacityKwh,
    this.connectorType,
    this.stationName,
    this.providerType,
    this.accessType,
    this.address,
    this.latitude,
    this.longitude,
    this.powerKw,
    this.pricePerKwh,
  });

  final String? vehicleType;
  final String? model;
  final String? brand;
  final String? registrationNumber;
  final double? batteryCapacityKwh;
  final String? connectorType;
  final String? stationName;
  final String? providerType;
  final String? accessType;
  final String? address;
  final double? latitude;
  final double? longitude;
  final double? powerKw;
  final double? pricePerKwh;
}

class SetupScreen extends StatefulWidget {
  const SetupScreen({required this.role, required this.onComplete, super.key});

  final UserRole role;

  /// Persists the role-specific setup and returns the route to show next (the
  /// role's home). Throwing keeps the user on this screen so nothing is lost.
  final Future<String> Function(SetupData data) onComplete;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{
    for (final key in [
      'vehicleType',
      'model',
      'brand',
      'registration',
      'battery',
      'stationName',
      'address',
      'latitude',
      'longitude',
      'powerKw',
      'price',
    ])
      key: TextEditingController(),
  };
  bool _busy = false;

  /// Selected options. The backend stores these as plain strings, so the form
  /// offers the canonical values as dropdowns instead of free text.
  String? _providerType = 'HOUSEHOLD';
  String? _accessType = 'PUBLIC';
  String? _connector;

  /// Station position captured through GPS. Coordinates belong to the station
  /// record, so an unset value blocks submission instead of submitting 0,0.
  double? _latitudeValue;
  double? _longitudeValue;
  bool _locating = false;
  String? _locationError;

  /// Manual coordinate entry is a fallback for when the device cannot provide
  /// a position (permission denied, location services off).
  bool _manualCoordinates = false;

  TextEditingController get _vehicleType => _controllers['vehicleType']!;
  TextEditingController get _model => _controllers['model']!;
  TextEditingController get _brand => _controllers['brand']!;
  TextEditingController get _registration => _controllers['registration']!;
  TextEditingController get _battery => _controllers['battery']!;
  TextEditingController get _stationName => _controllers['stationName']!;
  TextEditingController get _address => _controllers['address']!;
  TextEditingController get _latitude => _controllers['latitude']!;
  TextEditingController get _longitude => _controllers['longitude']!;
  TextEditingController get _powerKw => _controllers['powerKw']!;
  TextEditingController get _price => _controllers['price']!;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty ? '$label is required' : null;

  String? _positive(String? value, String label, {bool allowZero = false}) {
    final number = double.tryParse(value?.trim() ?? '');
    if (number == null || (allowZero ? number < 0 : number <= 0)) {
      return '$label must be a valid ${allowZero ? 'non-negative' : 'positive'} number';
    }
    return null;
  }

  String? _coordinate(
    String? value,
    String label,
    double minimum,
    double maximum,
  ) {
    final number = double.tryParse(value?.trim() ?? '');
    if (number == null || number < minimum || number > maximum) {
      return '$label must be between $minimum and $maximum';
    }
    return null;
  }

  Future<void> _finish() async {
    if (_busy) return;
    final provider = widget.role == UserRole.chargerProvider;

    // A station must have a real position. Validate the captured GPS value (or
    // the manual fallback) before anything is submitted, so the user never gets
    // an opaque server error about invalid coordinates.
    double? latitude;
    double? longitude;
    if (provider) {
      latitude = _latitudeValue ?? double.tryParse(_latitude.text.trim());
      longitude = _longitudeValue ?? double.tryParse(_longitude.text.trim());
      final validPosition =
          latitude != null &&
          longitude != null &&
          latitude >= -90 &&
          latitude <= 90 &&
          longitude >= -180 &&
          longitude <= 180;
      if (!validPosition) {
        setState(() {
          _locationError =
              'Set the station position with "Use current location" (or enter '
              'valid coordinates manually).';
        });
        return;
      }
      if (_connector == null) {
        _showMessage(context, 'Select the charger connector type.');
        return;
      }
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _locationError = null;
    });
    final data = provider
        ? SetupData(
            stationName: _stationName.text.trim(),
            providerType: _providerType ?? 'HOUSEHOLD',
            accessType: _accessType ?? 'PUBLIC',
            address: _address.text.trim(),
            latitude: latitude,
            longitude: longitude,
            connectorType: _connector,
            powerKw: double.parse(_powerKw.text.trim()),
            pricePerKwh: _price.text.trim().isEmpty
                ? null
                : double.parse(_price.text.trim()),
          )
        : SetupData(
            vehicleType: _vehicleType.text.trim(),
            model: _model.text.trim(),
            brand: _brand.text.trim(),
            registrationNumber: _registration.text.trim(),
            batteryCapacityKwh: _battery.text.trim().isEmpty
                ? null
                : double.parse(_battery.text.trim()),
            connectorType: _connector,
          );
    try {
      // The app state persists everything and returns the destination it reads
      // back from the backend profile, so this screen never guesses the home.
      final destination = await widget.onComplete(data);
      if (!mounted) return;
      // `go` (not push) so a finished setup cannot be reached again from the
      // back stack.
      context.go(destination);
    } catch (error) {
      if (mounted) {
        _showMessage(context, 'Could not save setup: ${errorMessageOf(error)}');
        setState(() => _busy = false);
      }
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator ?? (required ? (v) => _required(v, label) : null),
      decoration: InputDecoration(labelText: label),
    ),
  );

  /// Connector labels a user can pick for a vehicle or a charger. They are
  /// stored verbatim (the backend column is free text), so keeping the list
  /// identical for both roles makes the compatibility check meaningful.
  static const _connectorOptions = [
    'Type 2',
    'CCS1',
    'CCS2',
    'CHAdeMO',
    'Type 1',
  ];

  Widget _dropdown(
    String label,
    String? value,
    List<String> options,
    ValueChanged<String?> onChanged, {
    bool required = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final option in options)
          DropdownMenuItem(value: option, child: Text(option)),
      ],
      onChanged: onChanged,
      validator: required
          ? (selected) => selected == null ? '$label is required' : null
          : null,
    ),
  );

  /// Station position: GPS capture with an explicit manual fallback. Nothing is
  /// submitted while the position is unknown.
  Widget _locationCard() {
    final latitude = _latitudeValue;
    final longitude = _longitudeValue;
    final captured = latitude != null && longitude != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: .07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                captured ? Icons.place : Icons.place_outlined,
                color: captured ? AppColors.emerald : AppColors.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  captured
                      ? 'Station position: ${latitude.toStringAsFixed(5)}, '
                            '${longitude.toStringAsFixed(5)}'
                      : 'No station position selected yet',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: captured ? AppColors.ink : AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'This is the fixed location of the charger, not your live position '
            'while driving.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _locating ? null : _useCurrentLocation,
            icon: _locating
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            label: Text(
              _locating
                  ? 'Getting your location...'
                  : captured
                  ? 'Update current location'
                  : 'Use current location',
            ),
          ),
          if (_locationError != null) ...[
            const SizedBox(height: 10),
            Text(
              _locationError!,
              style: TextStyle(color: Colors.red.shade800, fontSize: 12),
            ),
          ],
          TextButton(
            onPressed: () =>
                setState(() => _manualCoordinates = !_manualCoordinates),
            child: Text(
              _manualCoordinates
                  ? 'Hide coordinate entry'
                  : 'Enter coordinates manually',
            ),
          ),
          if (_manualCoordinates) ...[
            _field(
              _latitude,
              'Latitude',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? null
                  : _coordinate(v, 'Latitude', -90, 90),
            ),
            _field(
              _longitude,
              'Longitude',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? null
                  : _coordinate(v, 'Longitude', -180, 180),
            ),
          ],
        ],
      ),
    );
  }

  /// Asks the device for its position. Every failure mode is reported in the
  /// card with the manual entry offered as the fallback; coordinates are never
  /// invented.
  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _locationError = null;
    });
    final result = await const LocationService().getCurrentLocation();
    if (!mounted) return;
    final location = result.location;
    setState(() {
      _locating = false;
      if (location == null) {
        _locationError = switch (result.status) {
          LocationStatus.denied =>
            'Location permission was denied. Allow it, or enter the '
                'coordinates manually.',
          LocationStatus.deniedForever =>
            'Location permission is blocked for this app. Enable it in system '
                'settings, or enter the coordinates manually.',
          LocationStatus.serviceDisabled =>
            'Location services are off on this device. Turn them on, or enter '
                'the coordinates manually.',
          _ =>
            'Could not determine your location. Try again, or enter the '
                'coordinates manually.',
        };
        return;
      }
      _latitudeValue = location.latitude;
      _longitudeValue = location.longitude;
      _latitude.text = location.latitude.toStringAsFixed(6);
      _longitude.text = location.longitude.toStringAsFixed(6);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.role == UserRole.chargerProvider;
    return Scaffold(
      appBar: AppBar(
        title: Text(provider ? 'Set up your charger' : 'Set up your vehicle'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              provider
                  ? 'These fields are required to create your station listing.'
                  : 'Add the vehicle details required for charging bookings.',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 22),
            if (provider) ...[
              _field(_stationName, 'Station name', required: true),
              _dropdown(
                'Provider type',
                _providerType,
                const ['HOUSEHOLD', 'PUBLIC'],
                (value) => setState(() => _providerType = value),
              ),
              _dropdown(
                'Access type',
                _accessType,
                const ['PUBLIC', 'PRIVATE'],
                (value) => setState(() => _accessType = value),
              ),
              _field(_address, 'Address', required: true),
              _locationCard(),
              _dropdown(
                'Charger connector type',
                _connector,
                _connectorOptions,
                (value) => setState(() => _connector = value),
                required: true,
              ),
              _field(
                _powerKw,
                'Power (kW)',
                required: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) => _positive(v, 'Power'),
              ),
              _field(
                _price,
                'Price per kWh (optional)',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? null
                    : _positive(v, 'Price', allowZero: true),
              ),
            ] else ...[
              _field(_vehicleType, 'Vehicle type', required: true),
              _field(_model, 'Model', required: true),
              _field(_brand, 'Brand'),
              _field(_registration, 'Registration number'),
              _field(
                _battery,
                'Battery capacity (kWh)',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? null
                    : _positive(v, 'Battery capacity'),
              ),
              _dropdown(
                'Connector type',
                _connector,
                _connectorOptions,
                (value) => setState(() => _connector = value),
              ),
            ],
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : _finish,
              child: _busy
                  ? const CircularProgressIndicator()
                  : const Text('Save and continue'),
            ),
          ],
        ),
      ),
    );
  }
}

class ProviderDashboardScreen extends StatelessWidget {
  const ProviderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Provider dashboard'),
      actions: [
        IconButton(
          tooltip: 'Profile',
          onPressed: () => context.go('/profile'),
          icon: const Icon(Icons.person_outline),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Manage your charging network',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Keep listings accurate and respond to incoming requests.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 24),
        _ProviderAction(
          icon: Icons.ev_station_outlined,
          title: 'My chargers',
          subtitle: 'View your stations and their listings',
          onTap: () => context.push('/provider/stations'),
        ),
        _ProviderAction(
          icon: Icons.schedule_outlined,
          title: 'Availability',
          subtitle: 'Publish when your charger can be booked',
          onTap: () => context.push('/provider/stations'),
        ),
        _ProviderAction(
          icon: Icons.inbox_outlined,
          title: 'Booking requests',
          subtitle: 'Review and respond to requests',
          onTap: () => context.push('/provider/bookings'),
        ),
        _ProviderAction(
          icon: Icons.history,
          title: 'Charging history',
          subtitle: 'Review completed sessions',
          onTap: () => _showMessage(
            context,
            'Charging history is not connected in this build.',
          ),
        ),
      ],
    ),
  );
}

/// Incoming booking requests for every station the signed-in provider owns.
///
/// Reads `GET /api/stations/{id}/bookings` per station and sends decisions to
/// `PUT /api/bookings/{id}/confirm` / `/reject`. The UI never flips a status by
/// itself: after each action it re-reads the server, so a request the backend
/// rejects (for example 409 "Booking is not pending") is reported as an error
/// instead of a fake success.
class ProviderBookingsScreen extends ConsumerWidget {
  const ProviderBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stationsAsync = ref.watch(myStationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Booking requests')),
      body: AsyncValueView<List<Station>>(
        value: stationsAsync,
        loadingLabel: 'Loading your stations…',
        onRetry: () => ref.invalidate(myStationsProvider),
        empty: () => const AppEmptyView(
          icon: Icons.inbox_outlined,
          title: 'No stations yet',
          message: 'Requests appear here once you have published a charger.',
        ),
        builder: (stations) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Requests by charger',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Confirm or reject pending requests. Owners see the decision '
              'immediately.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            for (final station in stations) _StationRequests(station: station),
          ],
        ),
      ),
    );
  }
}

class _StationRequests extends ConsumerWidget {
  const _StationRequests({required this.station});

  final Station station;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(stationBookingsProvider(station.id));
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            station.name,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          requests.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  errorMessageOf(error),
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(
                    stationBookingsProvider(station.id),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
            data: (bookings) {
              if (bookings.isEmpty) {
                return const Text(
                  'No requests yet.',
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                );
              }
              return Column(
                children: [
                  for (final booking in bookings)
                    _requestRow(context, ref, booking),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _requestRow(BuildContext context, WidgetRef ref, Booking booking) {
    final pending = booking.status == 'PENDING';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${booking.dateLabel} • ${booking.timeLabel}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 4),
                StatusBadge(status: booking.displayStatus),
              ],
            ),
          ),
          if (pending) ...[
            TextButton(
              onPressed: () => _decide(context, ref, booking, confirm: false),
              child: const Text('Reject'),
            ),
            const SizedBox(width: 4),
            FilledButton(
              onPressed: () => _decide(context, ref, booking, confirm: true),
              child: const Text('Confirm'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref,
    Booking booking, {
    required bool confirm,
  }) async {
    final id = booking.id;
    if (id == null) return;
    try {
      final api = ref.read(backendApiServiceProvider);
      if (confirm) {
        await api.confirmBooking(id);
      } else {
        await api.rejectBooking(id);
      }
      // Re-read server state rather than assuming the transition happened.
      ref.invalidate(stationBookingsProvider(booking.stationId.toString()));
      ref.invalidate(bookingsProvider);
      if (context.mounted) {
        _showMessage(context, confirm ? 'Booking confirmed.' : 'Booking rejected.');
      }
    } catch (error) {
      if (!context.mounted) return;
      _showMessage(context, errorMessageOf(error));
      ref.invalidate(stationBookingsProvider(booking.stationId.toString()));
    }
  }
}

/// Provider management screen: lists the signed-in provider's own stations
/// and lets them publish or remove availability windows. Publishing a window
/// is what makes a slot bookable by vehicle owners — the backend rejects any
/// booking that does not fall inside one.
class ProviderStationsScreen extends ConsumerStatefulWidget {
  const ProviderStationsScreen({super.key});

  @override
  ConsumerState<ProviderStationsScreen> createState() =>
      _ProviderStationsScreenState();
}

class _ProviderStationsScreenState
    extends ConsumerState<ProviderStationsScreen> {
  String? _selectedStationId;

  @override
  Widget build(BuildContext context) {
    final myAsync = ref.watch(myStationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My chargers')),
      body: AsyncValueView<List<Station>>(
        value: myAsync,
        loadingLabel: 'Loading your stations…',
        onRetry: () => ref.invalidate(myStationsProvider),
        empty: () => const AppEmptyView(
          icon: Icons.ev_station_outlined,
          title: 'No stations yet',
          message: 'Stations you list during setup appear here.',
        ),
        builder: (stations) {
          Station selected = stations.first;
          for (final candidate in stations) {
            if (candidate.id == _selectedStationId) selected = candidate;
          }
          final stationId = int.tryParse(selected.id);
          final windowsAsync = ref.watch(availabilityProvider(selected.id));

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Manage availability',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Vehicle owners can only book the windows you publish here.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              if (stations.length > 1)
                DropdownButtonFormField<String>(
                  initialValue: selected.id,
                  decoration: const InputDecoration(labelText: 'Station'),
                  items: stations
                      .map(
                        (s) =>
                            DropdownMenuItem(value: s.id, child: Text(s.name)),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedStationId = value),
                )
              else
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    selected.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: selected.active,
                title: const Text(
                  'Listing visible to drivers',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  selected.active
                      ? 'Appears in nearby searches.'
                      : 'Hidden from search. Publish it again to take bookings.',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                onChanged: stationId == null
                    ? null
                    : (value) => _setActive(stationId, value, selected.id),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Availability windows',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    '${windowsAsync.value?.length ?? 0} published',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AsyncValueView<List<AvailabilityWindow>>(
                value: windowsAsync,
                loadingLabel: 'Loading availability…',
                onRetry: () =>
                    ref.invalidate(availabilityProvider(selected.id)),
                empty: () => const AppEmptyView(
                  compact: true,
                  icon: Icons.schedule,
                  title: 'No availability published',
                  message: 'Add a time window so owners can book this charger.',
                ),
                builder: (windows) => Column(
                  children: [
                    for (final window in windows)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 18,
                              color: AppColors.emerald,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${DateFormat('EEE d MMM').format(window.start.toLocal())}  '
                                '${_clock(window.start)} – ${_clock(window.end)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            StatusBadge(
                              status: window.status.isEmpty
                                  ? window.status
                                  : window.status[0].toUpperCase() +
                                        window.status
                                            .substring(1)
                                            .toLowerCase(),
                            ),
                            IconButton(
                              tooltip: 'Remove window',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: stationId == null || window.id == null
                                  ? null
                                  : () => _deleteWindow(
                                      stationId,
                                      window.id!,
                                      selected.id,
                                    ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: stationId == null
                    ? null
                    : () => _addWindow(stationId, selected.id),
                icon: const Icon(Icons.add),
                label: const Text('Add availability window'),
              ),
              const SizedBox(height: 28),
            ],
          );
        },
      ),
    );
  }

  /// Publishes or hides the listing (`PUT /api/stations/{id}/status`).
  /// Ownership and role are enforced by the backend, not by this screen.
  Future<void> _setActive(
    int stationId,
    bool active,
    String providerKey,
  ) async {
    try {
      await ref
          .read(backendApiServiceProvider)
          .setStationActive(stationId, active: active);
      ref.invalidate(myStationsProvider);
      ref.invalidate(stationsProvider);
      ref.invalidate(availabilityProvider(providerKey));
      if (mounted) {
        _showMessage(
          context,
          active ? 'Listing published.' : 'Listing hidden from search.',
        );
      }
    } catch (error) {
      if (mounted) _showMessage(context, errorMessageOf(error));
    }
  }

  Future<void> _addWindow(int stationId, String providerKey) async {
    final created = await showDialog<(DateTime, DateTime)>(
      context: context,
      builder: (_) => const AddAvailabilityDialog(),
    );
    if (created == null || !mounted) return;
    try {
      await ref
          .read(backendApiServiceProvider)
          .addAvailability(stationId, start: created.$1, end: created.$2);
      ref.invalidate(availabilityProvider(providerKey));
      ref.invalidate(stationsProvider);
      if (mounted) {
        _showMessage(context, 'Availability window published.');
      }
    } catch (error) {
      if (mounted) _showMessage(context, errorMessageOf(error));
    }
  }

  Future<void> _deleteWindow(
    int stationId,
    int windowId,
    String providerKey,
  ) async {
    try {
      await ref
          .read(backendApiServiceProvider)
          .deleteAvailability(stationId, windowId);
      ref.invalidate(availabilityProvider(providerKey));
      ref.invalidate(stationsProvider);
    } catch (error) {
      if (mounted) _showMessage(context, errorMessageOf(error));
    }
  }
}

/// Date/time picker dialog that returns the chosen window, or null on cancel.
class AddAvailabilityDialog extends StatefulWidget {
  const AddAvailabilityDialog({super.key});
  @override
  State<AddAvailabilityDialog> createState() => _AddAvailabilityDialogState();
}

class _AddAvailabilityDialogState extends State<AddAvailabilityDialog> {
  late DateTime _start;
  late DateTime _end;
  String? _error;

  @override
  void initState() {
    super.initState();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _start = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 8);
    _end = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 20);
  }

  Future<void> _pick(bool isStart) async {
    final current = isStart ? _start : _end;
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 180)),
      initialDate: current,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;
    final combined = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isStart) {
        _start = combined;
        if (!_end.isAfter(_start)) {
          _end = _start.add(const Duration(hours: 1));
        }
      } else {
        _end = combined;
      }
      _error = null;
    });
  }

  void _save() {
    if (!_end.isAfter(_start)) {
      setState(() => _error = 'The end time must be after the start time.');
      return;
    }
    Navigator.of(context).pop((_start, _end));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add availability window'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.play_arrow, color: AppColors.emerald),
          title: const Text('Starts'),
          subtitle: Text(DateFormat('EEE d MMM yyyy • HH:mm').format(_start)),
          onTap: () => _pick(true),
        ),
        ListTile(
          leading: const Icon(Icons.stop, color: AppColors.emerald),
          title: const Text('Ends'),
          subtitle: Text(DateFormat('EEE d MMM yyyy • HH:mm').format(_end)),
          onTap: () => _pick(false),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: TextStyle(color: Colors.red.shade800, fontSize: 13),
            ),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Publish')),
    ],
  );
}

class _ProviderAction extends StatelessWidget {
  const _ProviderAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: AppColors.surface,
        child: Icon(icon, color: AppColors.emerald),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({required this.onRegister, super.key});

  final Future<void> Function({
    required String fullName,
    required String email,
    required String password,
  })
  onRegister;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _busy = false;
  String? _errorMessage;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || _busy) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      await widget.onRegister(
        fullName: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      if (CognitoAuthService().isConfigured) {
        context.push(
          '/verify-email?email=${Uri.encodeComponent(_email.text.trim())}',
        );
      } else {
        // Without Cognito there is no verification step; continue to setup.
        context.go('/account-setup');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = errorMessageOf(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create account')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Create your Voltway account',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Set up your profile to access the right charging tools for your role.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 28),
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade800),
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _name,
            textInputAction: TextInputAction.next,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Full name is required'
                : null,
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (value) => value == null || !value.contains('@')
                ? 'Enter a valid email address'
                : null,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _password,
            obscureText: true,
            textInputAction: TextInputAction.next,
            validator: (value) => value == null || value.length < 8
                ? 'Password must be at least 8 characters'
                : null,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirmPassword,
            obscureText: true,
            validator: (value) =>
                value != _password.text ? 'Passwords do not match' : null,
            decoration: const InputDecoration(
              labelText: 'Confirm password',
              prefixIcon: Icon(Icons.lock_reset_outlined),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create account'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _busy ? null : () => context.pop(),
            child: const Text('Already have an account? Sign in'),
          ),
        ],
      ),
    ),
  );
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({
    required this.initialRole,
    required this.onSignIn,
    super.key,
  });

  final UserRole? initialRole;
  final Future<String> Function({
    required UserRole? selectedRole,
    required String email,
    required String password,
  })
  onSignIn;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  UserRole? _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) ||
        _password.text.length < 8 ||
        _busy) {
      if (_password.text.length < 8 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password must be at least 8 characters'),
          ),
        );
      }
      return;
    }
    setState(() => _busy = true);
    try {
      final destination = await widget.onSignIn(
        selectedRole: _selectedRole,
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      // `go` (not pushReplacement) so the login screen is not left on the
      // stack: a completed profile must never see registration or setup again.
      context.go(destination);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessageOf(error))));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 50),
          const Icon(Icons.bolt, size: 52, color: AppColors.emerald),
          const SizedBox(height: 18),
          const Text(
            'Welcome back',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sign in to manage your charging',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 36),
          if (widget.initialRole == null) ...[
            const Text(
              'Account type',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            SegmentedButton<UserRole>(
              segments: const [
                ButtonSegment(
                  value: UserRole.vehicleOwner,
                  label: Text('Vehicle owner'),
                  icon: Icon(Icons.electric_car_outlined),
                ),
                ButtonSegment(
                  value: UserRole.chargerProvider,
                  label: Text('Charger provider'),
                  icon: Icon(Icons.ev_station_outlined),
                ),
              ],
              selected: _selectedRole == null ? {} : {_selectedRole!},
              emptySelectionAllowed: true,
              onSelectionChanged: (roles) =>
                  setState(() => _selectedRole = roles.first),
            ),
            const SizedBox(height: 18),
          ],
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              validator: (value) => value == null || !value.contains('@')
                  ? 'Enter a valid email address'
                  : null,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _password,
            obscureText: true,
            validator: (value) => value == null || value.length < 8
                ? 'Password must be at least 8 characters'
                : null,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _busy || _selectedRole == null ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Sign in'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _busy ? null : () => context.push('/role'),
            child: const Text('New here? Create an account'),
          ),
        ],
      ),
    ),
  );
}

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    required this.email,
    required this.onVerify,
    super.key,
  });

  final String? email;

  /// Confirms the code with Cognito, signs the user in when possible and
  /// returns the route to continue to. Throwing shows the error in place.
  final Future<String> Function(String code) onVerify;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _code = TextEditingController();
  final _auth = CognitoAuthService();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_busy) return;
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter the verification code from your email.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final destination = await widget.onVerify(code);
      if (!mounted) return;
      if (destination == '/login') {
        // The registration password is gone (app restart), so verification
        // hands over to a normal sign-in instead of faking a session.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email verified. Sign in to finish your account.'),
          ),
        );
      }
      // `go` clears the registration/verification screens from the stack, so
      // they cannot be reached again with the back button.
      context.go(destination);
    } catch (error) {
      if (mounted) setState(() => _error = errorMessageOf(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    final email = widget.email?.trim() ?? '';
    if (email.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.resendVerificationCode(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A new verification code was sent.')),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = errorMessageOf(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Verify your email')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Enter the code sent to ${widget.email ?? 'your email address'}.'),
        const SizedBox(height: 20),
        if (_error != null)
          Text(_error!, style: TextStyle(color: Colors.red.shade800)),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Verification code'),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _confirm,
          child: _busy
              ? const CircularProgressIndicator()
              : const Text('Verify and continue'),
        ),
        TextButton(
          onPressed: _busy ? null : _resend,
          child: const Text('Resend code'),
        ),
      ],
    ),
  );
}

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'This screen does not exist.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
          // The router redirect sends signed-out users to sign-in and
          // signed-in users to their own home screen.
          FilledButton(
            onPressed: () => context.go('/home'),
            child: const Text('Go to my home screen'),
          ),
        ],
      ),
    ),
  );
}

class AppPage extends StatelessWidget {
  const AppPage({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => SafeArea(child: child);
}

class QuickAction extends StatelessWidget {
  const QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.emerald),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

/// Shows the next confirmed/pending booking from the API. Renders nothing
/// when there is no upcoming session instead of inventing one.
class UpcomingCard extends ConsumerWidget {
  const UpcomingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(bookingsProvider).value;
    if (bookings == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final upcoming =
        bookings
            .where(
              (b) =>
                  (b.status == 'PENDING' || b.status == 'CONFIRMED') &&
                  b.endTime.isAfter(now),
            )
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
    if (upcoming.isEmpty) return const SizedBox.shrink();

    final next = upcoming.first;
    final stations = ref.watch(stationsProvider).value ?? const [];
    String stationName = next.label;
    for (final station in stations) {
      if (station.id == '${next.stationId}') stationName = station.name;
    }
    final start = next.startTime.toLocal();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final day =
        DateTime(start.year, start.month, start.day) ==
            DateTime(now.year, now.month, now.day)
        ? 'Today'
        : DateTime(start.year, start.month, start.day) == tomorrow
        ? 'Tomorrow'
        : DateFormat('d MMM yyyy').format(start);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_available, color: AppColors.emerald),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Next charging session',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '$stationName • $day at ${_clock(start)}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

void _showMessage(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
