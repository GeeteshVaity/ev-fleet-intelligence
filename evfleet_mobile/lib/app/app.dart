import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/backend_api_service.dart';
import '../core/errors/error_handler.dart';
import '../features/auth/data/cognito_auth_service.dart';

class AppColors {
  static const forest = Color(0xFF12372A);
  static const emerald = Color(0xFF1D7A55);
  static const lime = Color(0xFFC8E86B);
  static const surface = Color(0xFFF5F7F5);
  static const ink = Color(0xFF1D2B25);
  static const muted = Color(0xFF718078);
}

final stationsProvider = Provider<List<Station>>((ref) => demoStations);
final vehiclesProvider = StateProvider<List<Vehicle>>((ref) => demoVehicles);
final bookingsProvider = StateProvider<List<Booking>>((ref) => demoBookings);

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

  @override
  void initState() {
    super.initState();
    _restoreOnboarding();
  }

  Future<void> _restoreOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('onboarding.role');
    if (!mounted) return;
    var signedIn = prefs.getBool('session.signed_in') ?? false;
    if (_auth.isConfigured) {
      try {
        signedIn = await _auth.restoreSession() != null;
      } catch (_) {
        signedIn = false;
      }
    }
    if (!mounted) return;
    setState(() {
      _role = value == 'CHARGER_PROVIDER'
          ? UserRole.chargerProvider
          : value == 'VEHICLE_OWNER'
          ? UserRole.vehicleOwner
          : null;
      _onboardingComplete = prefs.getBool('onboarding.completed') ?? false;
      _signedIn = signedIn;
      _ready = true;
    });
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
    if (_auth.isConfigured) {
      final user = await _auth.signIn(email: email, password: password);
      await ref.read(backendApiServiceProvider).saveProfile(
        fullName: user.fullName,
        email: user.email,
        role: (_role ?? selectedRole ?? UserRole.vehicleOwner).wireValue,
      );
    }
    final prefs = await SharedPreferences.getInstance();
    if (_role == null && selectedRole != null) {
      await prefs.setString('onboarding.role', selectedRole.wireValue);
      _role = selectedRole;
    }
    await prefs.setBool('session.signed_in', true);
    _signedIn = true;
    return _onboardingComplete ? _homePath : '/setup';
  }

  Future<void> _register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    if (_auth.isConfigured) {
      await _auth.signUp(fullName: fullName, email: email, password: password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_verification.email', email);
      await prefs.setString('pending_verification.name', fullName);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await ref
        .read(backendApiServiceProvider)
        .saveProfile(fullName: fullName, email: email, role: _role!.wireValue);
    await prefs.setString('account.full_name', fullName);
    await prefs.setString('account.email', email);
    await prefs.setBool('session.signed_in', true);
    _signedIn = true;
  }

  Future<void> _signOut() async {
    if (_auth.isConfigured) {
      await _auth.signOut();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('session.signed_in', false);
    _signedIn = false;
  }

  Future<void> _updateProfile({
    required String fullName,
    required String email,
    String? phone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await ref
        .read(backendApiServiceProvider)
        .updateProfile(fullName: fullName, email: email, phone: phone);
    await prefs.setString('account.full_name', fullName);
    await prefs.setString('account.email', email);
    if (phone != null) await prefs.setString('account.phone', phone);
  }

  Future<void> _completeOnboarding(SetupData data) async {
    final prefs = await SharedPreferences.getInstance();
    final api = ref.read(backendApiServiceProvider);
    if (_role == UserRole.vehicleOwner) {
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
    await api.saveOnboarding(role: _role!.wireValue, completed: true, step: 1);
    await prefs.setBool('onboarding.completed', true);
    _onboardingComplete = true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    final router = GoRouter(
      initialLocation: !_signedIn
          ? '/signin'
          : _role == null
          ? '/signin'
          : _onboardingComplete
          ? _homePath
          : '/setup',
      redirect: (context, state) {
        final location = state.matchedLocation;
        if (_role != null &&
            !_signedIn &&
            location != '/signin' &&
            location != '/register' &&
            location != '/role' &&
            location != '/verify-email') {
          return '/signin';
        }
        if (_role == null &&
            !_signedIn &&
            location != '/signin' &&
            location != '/register' &&
            location != '/role' &&
            location != '/verify-email') {
          return '/signin';
        }
        if (_role != null &&
            _signedIn &&
            !_onboardingComplete &&
            location != '/setup' &&
            location != '/register' &&
            location != '/role') {
          return '/setup';
        }
        if (_role == UserRole.chargerProvider &&
            _signedIn &&
            (location.startsWith('/home') ||
                location.startsWith('/explore') ||
                location.startsWith('/bookings') ||
                location.startsWith('/vehicles'))) {
          return '/provider';
        }
        if (_role == UserRole.vehicleOwner &&
            _signedIn &&
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
          path: '/setup',
          builder: (_, __) =>
              SetupScreen(role: _role!, onComplete: _completeOnboarding),
        ),
        GoRoute(
          path: '/provider',
          builder: (_, __) => const ProviderDashboardScreen(),
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
          path: '/signin',
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
          ),
        ),
      ],
      errorBuilder: (_, __) => const NotFoundScreen(),
    );
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
    required this.available,
    required this.provider,
    this.rating,
  });
  final String id, name, address, distance, power, connector, price, provider;
  final int available;
  final double? rating;
}

class Vehicle {
  const Vehicle({
    required this.name,
    required this.details,
    required this.connector,
    required this.battery,
  });
  final String name, details, connector;
  final double battery;
}

class Booking {
  const Booking({
    required this.station,
    required this.date,
    required this.time,
    required this.status,
  });
  final String station, date, time, status;
}

const demoStations = [
  Station(
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
  Station(
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
  Station(
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

const demoVehicles = [
  Vehicle(
    name: 'Tesla Model 3',
    details: '2023 • Long Range',
    connector: 'CCS2',
    battery: 75,
  ),
  Vehicle(
    name: 'Nissan Leaf',
    details: '2021 • Tekna',
    connector: 'CHAdeMO',
    battery: 40,
  ),
];

const demoBookings = [
  Booking(
    station: 'Green Square Hub',
    date: 'Tomorrow',
    time: '09:30 - 10:30',
    status: 'Confirmed',
  ),
  Booking(
    station: 'HomeCharge by Maya',
    date: '12 Jun 2026',
    time: '18:00 - 19:00',
    status: 'Completed',
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
    final stations = ref.watch(stationsProvider);
    return AppPage(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 23,
                backgroundColor: AppColors.forest,
                child: Text(
                  'JD',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good morning, Jordan',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
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
                        '6 stations available nearby',
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
                  'Station listing form will connect to your API.',
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
          ...stations
              .take(2)
              .map(
                (station) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: StationCard(station: station),
                ),
              ),
          const SizedBox(height: 8),
          const UpcomingCard(),
        ],
      ),
    );
  }
}

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});
  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  bool map = false;
  String query = '';
  @override
  Widget build(BuildContext context) {
    final stations = ref
        .watch(stationsProvider)
        .where(
          (s) =>
              s.name.toLowerCase().contains(query.toLowerCase()) ||
              s.address.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
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
                    'Filters are ready for backend availability data.',
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
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: stations
                        .map(
                          (s) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: StationCard(station: s),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class DemoMap extends StatelessWidget {
  const DemoMap({super.key});
  @override
  Widget build(BuildContext context) => Container(
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
            'Live station map',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
      ],
    ),
  );
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
              _Info(icon: Icons.near_me, value: station.distance),
              _Info(icon: Icons.bolt, value: station.power),
              _Info(icon: Icons.power, value: station.connector),
              const Spacer(),
              Text(
                '${station.available} free',
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
    final station = ref
        .watch(stationsProvider)
        .firstWhere((s) => s.id == id, orElse: () => demoStations.first);
    return Scaffold(
      appBar: AppBar(title: const Text('Station details')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            height: 190,
            decoration: BoxDecoration(
              color: const Color(0xFFDDE9DF),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
              child: Icon(Icons.ev_station, size: 80, color: AppColors.emerald),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            station.name,
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
              Text(
                station.address,
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 20),
          StationCard(station: station),
          const SizedBox(height: 20),
          const Text(
            'About this station',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'A reliable charging point with easy access and clear pricing. Availability is supplied by the station owner and confirmed by the server when you book.',
            style: TextStyle(color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.push('/book/${station.id}'),
            icon: const Icon(Icons.calendar_month),
            label: const Text('Book charging slot'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
            ),
          ),
        ],
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
  String? vehicle;
  String? time;
  @override
  Widget build(BuildContext context) {
    final station = ref
        .watch(stationsProvider)
        .firstWhere(
          (s) => s.id == widget.stationId,
          orElse: () => demoStations.first,
        );
    final vehicles = ref.watch(vehiclesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Book a slot')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            station.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Availability is confirmed when you submit the request.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 26),
          const Text(
            'Choose a vehicle',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: vehicle,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.directions_car_outlined),
              labelText: 'Vehicle',
            ),
            items: vehicles
                .map(
                  (v) => DropdownMenuItem(value: v.name, child: Text(v.name)),
                )
                .toList(),
            onChanged: (v) => setState(() => vehicle = v),
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
              if (picked != null) setState(() => date = picked);
            },
            icon: const Icon(Icons.calendar_today),
            label: Align(
              alignment: Alignment.centerLeft,
              child: Text(DateFormat('EEEE, d MMMM').format(date)),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Available start time',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['08:00', '09:30', '11:00', '14:30', '18:00']
                .map(
                  (value) => ChoiceChip(
                    label: Text(value),
                    selected: time == value,
                    onSelected: (_) => setState(() => time = value),
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
                    'Pricing and availability are estimates until the backend confirms this booking.',
                    style: TextStyle(color: AppColors.forest),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: vehicle == null || time == null
                ? null
                : () {
                    ref
                        .read(bookingsProvider.notifier)
                        .update(
                          (items) => [
                            Booking(
                              station: station.name,
                              date: DateFormat('d MMM yyyy').format(date),
                              time: '$time - ${_endTime(time!)}',
                              status: 'Pending',
                            ),
                            ...items,
                          ],
                        );
                    context.go('/bookings');
                    _showMessage(
                      context,
                      'Booking request submitted for confirmation.',
                    );
                  },
            child: const Text('Request booking'),
          ),
        ],
      ),
    );
  }

  String _endTime(String start) {
    final parts = start.split(':');
    final hour = (int.parse(parts[0]) + 1).toString().padLeft(2, '0');
    return '$hour:${parts[1]}';
  }
}

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(bookingsProvider);
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
          ...bookings.map((booking) => BookingCard(booking: booking)),
        ],
      ),
    );
  }
}

class BookingCard extends StatelessWidget {
  const BookingCard({required this.booking, super.key});
  final Booking booking;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
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
                booking.station,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              Text(
                '${booking.date} • ${booking.time}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        StatusBadge(status: booking.status),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: (active ? AppColors.lime : Colors.grey.shade200).withValues(
          alpha: .55,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          color: active ? AppColors.forest : AppColors.muted,
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
    final vehicles = ref.watch(vehiclesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My vehicles')),
      body: ListView(
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
                  const Icon(Icons.more_vert),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _showMessage(
              context,
              'Vehicle form is ready for persistence integration.',
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add vehicle'),
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({required this.onSignOut, super.key});

  final Future<void> Function() onSignOut;
  @override
  Widget build(BuildContext context) => AppPage(
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
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.forest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.lime,
                child: Text(
                  'JD',
                  style: TextStyle(
                    color: AppColors.forest,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jordan Davis',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    'jordan@example.com',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
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
            if (context.mounted) context.go('/signin');
          },
        ),
        const SizedBox(height: 20),
      ],
    ),
  );
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
  final Future<void> Function(SetupData data) onComplete;

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
      'connector',
      'stationName',
      'providerType',
      'accessType',
      'address',
      'latitude',
      'longitude',
      'powerKw',
      'price',
    ])
      key: TextEditingController(),
  };
  bool _busy = false;

  TextEditingController get _vehicleType => _controllers['vehicleType']!;
  TextEditingController get _model => _controllers['model']!;
  TextEditingController get _brand => _controllers['brand']!;
  TextEditingController get _registration => _controllers['registration']!;
  TextEditingController get _battery => _controllers['battery']!;
  TextEditingController get _connector => _controllers['connector']!;
  TextEditingController get _stationName => _controllers['stationName']!;
  TextEditingController get _providerType => _controllers['providerType']!;
  TextEditingController get _accessType => _controllers['accessType']!;
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
    if (!(_formKey.currentState?.validate() ?? false) || _busy) return;
    setState(() => _busy = true);
    final provider = widget.role == UserRole.chargerProvider;
    final data = provider
        ? SetupData(
            stationName: _stationName.text.trim(),
            providerType: _providerType.text.trim(),
            accessType: _accessType.text.trim(),
            address: _address.text.trim(),
            latitude: double.parse(_latitude.text.trim()),
            longitude: double.parse(_longitude.text.trim()),
            connectorType: _connector.text.trim(),
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
            connectorType: _connector.text.trim(),
          );
    try {
      await widget.onComplete(data);
      if (!mounted) return;
      context.pushReplacement(provider ? '/provider' : '/home');
    } catch (error) {
      if (mounted) {
        _showMessage(context, 'Could not save setup: $error');
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
              _field(
                _providerType,
                'Provider type (PUBLIC, BUSINESS, HOUSEHOLD)',
                required: true,
              ),
              _field(
                _accessType,
                'Access type (PUBLIC, PRIVATE)',
                required: true,
              ),
              _field(_address, 'Address', required: true),
              _field(
                _latitude,
                'Latitude',
                required: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) => _coordinate(v, 'Latitude', -90, 90),
              ),
              _field(
                _longitude,
                'Longitude',
                required: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) => _coordinate(v, 'Longitude', -180, 180),
              ),
              _field(_connector, 'Connector type', required: true),
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
              _field(_connector, 'Connector type'),
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
          subtitle: 'Add or edit your station details',
          onTap: () => _showMessage(
            context,
            'Charger management is ready for your API.',
          ),
        ),
        _ProviderAction(
          icon: Icons.inbox_outlined,
          title: 'Booking requests',
          subtitle: 'Review and respond to requests',
          onTap: () => _showMessage(context, 'No pending requests yet.'),
        ),
        _ProviderAction(
          icon: Icons.schedule_outlined,
          title: 'Availability',
          subtitle: 'Set when your charger is available',
          onTap: () => _showMessage(
            context,
            'Availability management is ready for your API.',
          ),
        ),
        _ProviderAction(
          icon: Icons.history,
          title: 'Charging history',
          subtitle: 'Review completed sessions',
          onTap: () => _showMessage(context, 'Charging history is ready.'),
        ),
      ],
    ),
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
        context.push('/setup');
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
  }) onSignIn;

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
      context.pushReplacement(destination);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessageOf(error))));
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
  const VerifyEmailScreen({required this.email, super.key});

  final String? email;

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
    final email = widget.email?.trim() ?? '';
    if (email.isEmpty || _code.text.trim().isEmpty) {
      setState(() => _error = 'Email and verification code are required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.confirmEmail(email: email, code: _code.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email verified. You can now sign in.')),
        );
        context.go('/signin');
      }
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
              : const Text('Verify email'),
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
      child: FilledButton(
        onPressed: () => context.go('/role'),
        child: const Text('Return home'),
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

class UpcomingCard extends StatelessWidget {
  const UpcomingCard({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: const Row(
      children: [
        Icon(Icons.event_available, color: AppColors.emerald),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Next charging session',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'Green Square Hub • Tomorrow at 09:30',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right),
      ],
    ),
  );
}

void _showMessage(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
