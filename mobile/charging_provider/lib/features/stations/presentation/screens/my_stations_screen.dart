
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class ProviderStationSummary {
  const ProviderStationSummary({
    required this.id,
    required this.stationName,
    required this.providerType,
    required this.address,
    required this.connectorType,
    required this.powerKw,
    required this.pricePerKwh,
    required this.isActive,
  });

  final String id;
  final String stationName;
  final String providerType;
  final String address;
  final String connectorType;
  final double powerKw;
  final double pricePerKwh;
  final bool isActive;
}

class MyStationsScreen extends StatefulWidget {
  const MyStationsScreen({
    super.key,
    required this.stations,
    required this.onOpenStation,
    required this.onManageAvailability,
    required this.onAddStation,
    required this.onNavigationChanged,
    required this.onToggleStation,
    required this.onDeactivateStation,
  });

  final List<ProviderStationSummary> stations;
  final ValueChanged<String> onOpenStation;
  final ValueChanged<String> onManageAvailability;
  final VoidCallback onAddStation;
  final ValueChanged<int> onNavigationChanged;
  final void Function(String id, bool active) onToggleStation;
  final ValueChanged<String> onDeactivateStation;

  @override
  State<MyStationsScreen> createState() => _MyStationsScreenState();
}

class _MyStationsScreenState extends State<MyStationsScreen> {
  final _searchController = TextEditingController();

  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All',
    'Active',
    'Inactive',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ProviderStationSummary> get _filteredStations {
    final query = _searchController.text.trim().toLowerCase();

    return widget.stations.where((station) {
      final matchesSearch =
          station.stationName.toLowerCase().contains(query) ||
          station.address.toLowerCase().contains(query);

      final matchesFilter = switch (_selectedFilter) {
        'Active' => station.isActive,
        'Inactive' => !station.isActive,
        _ => true,
      };

      return matchesSearch && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final filteredStations = _filteredStations;

    final activeCount =
        widget.stations.where((station) => station.isActive).length;

    final inactiveCount = widget.stations.length - activeCount;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.ev_station_rounded,
                color: AppColors.black,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EV Fleet',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'MY STATIONS',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    letterSpacing: 0.7,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => widget.onNavigationChanged(3),
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: 'Profile',
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  // Page heading
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Charging Stations',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Manage your registered charging stations.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Station summary
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          _SummaryChip(
                            label: 'Total',
                            count: widget.stations.length,
                          ),
                          const SizedBox(width: 8),
                          _SummaryChip(
                            label: 'Active',
                            count: activeCount,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 8),
                          _SummaryChip(
                            label: 'Inactive',
                            count: inactiveCount,
                            color: AppColors.neutral500,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Search
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search by station name or address',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),

                  // Filters
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _filters.map((filter) {
                            final selected = _selectedFilter == filter;

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(filter),
                                selected: selected,
                                onSelected: (_) {
                                  setState(() {
                                    _selectedFilter = filter;
                                  });
                                },
                                selectedColor: AppColors.primary,
                                labelStyle: TextStyle(
                                  color: selected
                                      ? AppColors.black
                                      : colors.onSurface,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                                side: BorderSide.none,
                                showCheckmark: false,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),

                  // Station count
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        '${filteredStations.length} '
                        '${filteredStations.length == 1 ? 'station' : 'stations'}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),

                  // Station list
                  if (filteredStations.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyStations(
                        hasSearch: _searchController.text.isNotEmpty ||
                            _selectedFilter != 'All',
                        onAddStation: widget.onAddStation,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      sliver: SliverList.separated(
                        itemCount: filteredStations.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final station = filteredStations[index];

                          return _StationCard(
                            station: station,
                            onTap: () => widget.onOpenStation(station.id),
                            onManageAvailability: () =>
                                widget.onManageAvailability(station.id),
                            onToggle: () => widget.onToggleStation(
                              station.id,
                              !station.isActive,
                            ),
                            onDeactivate: () => widget.onDeactivateStation(station.id),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),

      // Add station action
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onAddStation,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Station'),
      ),

      // Bottom navigation
      bottomNavigationBar: NavigationBar(
        selectedIndex: 1,
        onDestinationSelected: widget.onNavigationChanged,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.ev_station_outlined),
            selectedIcon: Icon(Icons.ev_station_rounded),
            label: 'Stations',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------
// Summary chip
// --------------------------------------------------

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.count,
    this.color,
  });

  final String label;
  final int count;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label ($count)',
        style: theme.textTheme.labelSmall?.copyWith(
          color: effectiveColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// --------------------------------------------------
// Station card
// --------------------------------------------------

class _StationCard extends StatelessWidget {
  const _StationCard({
    required this.station,
    required this.onTap,
    required this.onManageAvailability,
    required this.onToggle,
    required this.onDeactivate,
  });

  final ProviderStationSummary station;
  final VoidCallback onTap;
  final VoidCallback onManageAvailability;
  final VoidCallback onToggle;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final statusColor = station.isActive
        ? AppColors.success
        : AppColors.neutral500;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Station name and price
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 7,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _SmallBadge(
                              label: station.providerType,
                              color: colors.secondary,
                            ),
                            _SmallBadge(
                              label: station.isActive
                                  ? 'Active'
                                  : 'Inactive',
                              color: statusColor,
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        Text(
                          station.stationName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${station.pricePerKwh.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '/kWh',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),

                  PopupMenuButton<String>(
                    tooltip: 'Station actions',
                    onSelected: (value) {
                      if (value == 'toggle') {
                        onToggle();
                      } else if (value == 'availability') {
                        onManageAvailability();
                      } else if (value == 'deactivate') {
                        onDeactivate();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'availability',
                        child: Text('Manage availability'),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text(
                          station.isActive ? 'Set inactive' : 'Activate station',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'deactivate',
                        child: Text('Deactivate station'),
                      ),
                    ],
                    icon: const Icon(Icons.more_vert_rounded),
                  ),

                ],
              ),

              const SizedBox(height: 10),

              // Address
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      station.address,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Connector and power details
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(
                    alpha: 0.55,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _StationDetail(
                        icon: Icons.electrical_services_rounded,
                        label: 'Connector',
                        value: station.connectorType,
                      ),
                    ),
                    Container(
                      height: 32,
                      width: 1,
                      color: theme.dividerColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StationDetail(
                        icon: Icons.bolt_rounded,
                        label: 'Power Capacity',
                        value: '${station.powerKw} kW',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Details action
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'View Details',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: colors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------
// Station detail item
// --------------------------------------------------

class _StationDetail extends StatelessWidget {
  const _StationDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        Icon(
          icon,
          size: 19,
          color: colors.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------
// Small badge
// --------------------------------------------------

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// --------------------------------------------------
// Empty state
// --------------------------------------------------

class _EmptyStations extends StatelessWidget {
  const _EmptyStations({
    required this.hasSearch,
    required this.onAddStation,
  });

  final bool hasSearch;
  final VoidCallback onAddStation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasSearch
                  ? Icons.search_off_rounded
                  : Icons.ev_station_rounded,
              size: 52,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch ? 'No stations found' : 'No stations yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? 'Try another search or filter.'
                  : 'Add your first charging station to get started.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            if (!hasSearch) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onAddStation,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Station'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
