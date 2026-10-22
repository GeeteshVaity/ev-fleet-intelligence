import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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

class EvFleetApp extends ConsumerWidget {
  const EvFleetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const ShellScreen(index: 0)),
        GoRoute(
          path: '/explore',
          builder: (_, __) => const ShellScreen(index: 1),
        ),
        GoRoute(
          path: '/bookings',
          builder: (_, __) => const ShellScreen(index: 2),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, __) => const ShellScreen(index: 3),
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
        GoRoute(path: '/signin', builder: (_, __) => const SignInScreen()),
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
  const ShellScreen({required this.index, super.key});
  final int index;
  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  late int selected = widget.index;
  @override
  Widget build(BuildContext context) {
    final screens = const [
      HomeScreen(),
      ExploreScreen(),
      BookingsScreen(),
      ProfileScreen(),
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
                onTap: () => _demoMessage(
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
                  onPressed: () => _demoMessage(
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
            'Demo map • connect a map provider later',
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
            'Demo booking • server confirms final availability',
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
                    _demoMessage(
                      context,
                      'Demo booking created. Backend confirmation is still required.',
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
            onPressed: () => _demoMessage(
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
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => AppPage(
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Profile',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
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
          onTap: () => _demoMessage(
            context,
            'Notification preferences are not connected yet.',
          ),
        ),
        _ProfileItem(
          icon: Icons.settings_outlined,
          title: 'Settings',
          onTap: () => _demoMessage(
            context,
            'Settings are ready for your product configuration.',
          ),
        ),
        _ProfileItem(
          icon: Icons.logout,
          title: 'Sign out',
          onTap: () => context.go('/signin'),
        ),
        const SizedBox(height: 20),
        const Center(
          child: Text(
            'Demo mode • no real account or tokens are used',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
      ],
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

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});
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
          const TextField(
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 14),
          const TextField(
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: () => context.go('/home'),
            child: const Text('Continue in demo mode'),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Cognito authentication will be connected after AWS configuration is confirmed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
        ],
      ),
    ),
  );
}

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        onPressed: () => context.go('/home'),
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

void _demoMessage(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
