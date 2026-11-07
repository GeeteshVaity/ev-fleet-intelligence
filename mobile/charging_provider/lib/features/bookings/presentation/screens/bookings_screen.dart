
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class ProviderBooking {
  const ProviderBooking({
    required this.id,
    required this.stationName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.estimatedCost,
    required this.status,
    this.vehicleDetails,
  });

  final String id;
  final String stationName;
  final String date;
  final String startTime;
  final String endTime;
  final double estimatedCost;

  // Optional: display only when the API supplies this information.
  final String? vehicleDetails;

  final String status;
}

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({
    super.key,
    required this.bookings,
    required this.onOpenBooking,
    required this.onBookingDecision,
    required this.onNavigationChanged,
  });

  final List<ProviderBooking> bookings;
  final ValueChanged<String> onOpenBooking;

  final void Function(
    String bookingId,
    bool accepted,
  ) onBookingDecision;

  final ValueChanged<int> onNavigationChanged;

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  static const List<String> _filters = [
    'All',
    'Pending',
    'Confirmed',
    'Rejected',
    'Cancelled',
  ];

  String _selectedFilter = 'All';

  List<ProviderBooking> get _filteredBookings {
    if (_selectedFilter == 'All') {
      return widget.bookings;
    }

    return widget.bookings.where((booking) {
      return booking.status.toUpperCase() ==
          _selectedFilter.toUpperCase();
    }).toList();
  }

  int _countByStatus(String status) {
    return widget.bookings.where(
      (booking) => booking.status.toUpperCase() == status.toUpperCase(),
    ).length;
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return AppColors.warning;
      case 'CONFIRMED':
        return AppColors.success;
      case 'REJECTED':
        return AppColors.error;
      case 'CANCELLED':
        return AppColors.neutral500;
      default:
        return AppColors.neutral500;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final filteredBookings = _filteredBookings;

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
                  'BOOKING MANAGEMENT',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    letterSpacing: 0.6,
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
        child: CustomScrollView(
          slivers: [
            // Heading
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Station Bookings',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Review and manage your station booking requests.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Summary cards
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: _BookingSummaryCard(
                        title: 'Total Bookings',
                        value: widget.bookings.length.toString(),
                        icon: Icons.calendar_month_rounded,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BookingSummaryCard(
                        title: 'Pending',
                        value: _countByStatus('PENDING').toString(),
                        icon: Icons.pending_actions_rounded,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Filter heading
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Filter Bookings',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Filter chips
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map((filter) {
                      final isSelected = _selectedFilter == filter;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            filter == 'All'
                                ? 'All (${widget.bookings.length})'
                                : '$filter (${_countByStatus(filter)})',
                          ),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              _selectedFilter = filter;
                            });
                          },
                          selectedColor: AppColors.primary,
                          showCheckmark: false,
                          side: BorderSide.none,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? AppColors.black
                                : colors.onSurface,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            // Booking count
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              sliver: SliverToBoxAdapter(
                child: Text(
                  '${filteredBookings.length} '
                  '${filteredBookings.length == 1 ? 'booking' : 'bookings'}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),

            // Booking list
            if (filteredBookings.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyBookings(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList.separated(
                  itemCount: filteredBookings.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final booking = filteredBookings[index];

                    return _BookingCard(
                      booking: booking,
                      statusColor: _statusColor(booking.status),
                      onOpen: () =>
                          widget.onOpenBooking(booking.id),
                      onDecision: (accepted) {
                        widget.onBookingDecision(
                          booking.id,
                          accepted,
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),

      // Bottom navigation
      bottomNavigationBar: NavigationBar(
        selectedIndex: 2,
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
// Booking summary card
// --------------------------------------------------

class _BookingSummaryCard extends StatelessWidget {
  const _BookingSummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------
// Booking card
// --------------------------------------------------

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.statusColor,
    required this.onOpen,
    required this.onDecision,
  });

  final ProviderBooking booking;
  final Color statusColor;
  final VoidCallback onOpen;
  final ValueChanged<bool> onDecision;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final isPending =
        booking.status.toUpperCase() == 'PENDING';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status and booking ID
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    booking.status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '#${booking.id}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            // Station information
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.ev_station_rounded,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.stationName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (booking.vehicleDetails != null &&
                          booking.vehicleDetails!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          booking.vehicleDetails!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Date
            _BookingInfoRow(
              icon: Icons.calendar_today_outlined,
              label: booking.date,
            ),

            const SizedBox(height: 10),

            // Time
            _BookingInfoRow(
              icon: Icons.access_time_rounded,
              label: '${booking.startTime} – ${booking.endTime}',
            ),

            const SizedBox(height: 10),

            // Estimated cost
            _BookingInfoRow(
              icon: Icons.currency_rupee_rounded,
              label: 'Estimated Cost',
              value: '₹${booking.estimatedCost.toStringAsFixed(2)}',
            ),

            const SizedBox(height: 16),

            // Actions
            if (isPending)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => onDecision(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.error,
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => onDecision(true),
                      child: const Text('Confirm Booking'),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onOpen,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('View Details'),
                      SizedBox(width: 7),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------
// Booking information row
// --------------------------------------------------

class _BookingInfoRow extends StatelessWidget {
  const _BookingInfoRow({
    required this.icon,
    required this.label,
    this.value,
  });

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: colors.onSurfaceVariant,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        if (value != null)
          Text(
            value!,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }
}

// --------------------------------------------------
// Empty state
// --------------------------------------------------

class _EmptyBookings extends StatelessWidget {
  const _EmptyBookings();

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
              Icons.calendar_month_outlined,
              size: 54,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No bookings found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bookings matching this filter will appear here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
