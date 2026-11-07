
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class ProviderBookingSummary {
  const ProviderBookingSummary({
    required this.id,
    required this.stationName,
    required this.date,
    required this.time,
    required this.status,
    this.estimatedCost,
  });

  final String id;
  final String stationName;
  final String date;
  final String time;
  final String status;
  final double? estimatedCost;
}

class ProviderDashboardScreen extends StatelessWidget {
  const ProviderDashboardScreen({
    super.key,
    required this.providerName,
    required this.totalStations,
    required this.activeStations,
    required this.pendingBookings,
    required this.recentBookings,
    required this.onAddStation,
    required this.onOpenBooking,
    required this.onBookingDecision,
    required this.onNavigationChanged,
  });

  final String providerName;
  final int totalStations;
  final int activeStations;
  final int pendingBookings;
  final List<ProviderBookingSummary> recentBookings;

  final VoidCallback onAddStation;
  final ValueChanged<String> onOpenBooking;
  final void Function(String bookingId, bool accepted)
      onBookingDecision;
  final ValueChanged<int> onNavigationChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
                  'PROVIDER DASHBOARD',
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
            onPressed: () => onNavigationChanged(3),
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: 'Profile',
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting
              Text(
                'Good morning, $providerName',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Here is an overview of your charging stations.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 24),

              // Station and booking statistics
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Total Stations',
                      value: totalStations.toString(),
                      subtitle: '$activeStations active',
                      icon: Icons.ev_station_rounded,
                      iconColor: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Pending Bookings',
                      value: pendingBookings.toString(),
                      subtitle: 'Awaiting decision',
                      icon: Icons.event_note_rounded,
                      iconColor: AppColors.warning,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Recent bookings heading
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Bookings',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () => onNavigationChanged(2),
                    child: const Row(
                      children: [
                        Text('View all'),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Booking list
              if (recentBookings.isEmpty)
                _EmptyBookings(
                  onBrowseStations: onAddStation,
                )
              else
                ...recentBookings.map(
                  (booking) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _BookingCard(
                      booking: booking,
                      onTap: () => onOpenBooking(booking.id),
                      onDecision: onBookingDecision,
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              // Add station button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: onAddStation,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Charging Station'),
                ),
              ),
            ],
          ),
        ),
      ),

      // Bottom navigation
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: onNavigationChanged,
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
// Statistics card
// --------------------------------------------------

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ],
            ),

            const SizedBox(height: 14),

            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              subtitle,
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

// --------------------------------------------------
// Booking card
// --------------------------------------------------

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.onTap,
    required this.onDecision,
  });

  final ProviderBookingSummary booking;
  final VoidCallback onTap;
  final void Function(String bookingId, bool accepted) onDecision;

  Color _statusColor() {
    switch (booking.status.toUpperCase()) {
      case 'CONFIRMED':
        return AppColors.success;
      case 'PENDING':
        return AppColors.warning;
      case 'REJECTED':
      case 'CANCELLED':
        return AppColors.error;
      default:
        return AppColors.neutral500;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final isPending = booking.status.toUpperCase() == 'PENDING';
    final statusColor = _statusColor();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Booking heading
            Row(
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Booking #${booking.id}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                _StatusBadge(
                  status: booking.status,
                  color: statusColor,
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Date and time
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 15,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    booking.date,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 15,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    booking.time,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),

            if (booking.estimatedCost != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.currency_rupee_rounded,
                    size: 15,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Estimated cost: ${booking.estimatedCost!.toStringAsFixed(2)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],

            const SizedBox(height: 14),

            // Booking actions
            if (isPending)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        onDecision(booking.id, false);
                      },
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        onDecision(booking.id, true);
                      },
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onTap,
                  child: const Text('View Booking'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------
// Booking status badge
// --------------------------------------------------

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.status,
    required this.color,
  });

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// --------------------------------------------------
// Empty bookings state
// --------------------------------------------------

class _EmptyBookings extends StatelessWidget {
  const _EmptyBookings({
    required this.onBrowseStations,
  });

  final VoidCallback onBrowseStations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 42,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No bookings yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your recent booking activity will appear here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onBrowseStations,
              child: const Text('Add a charging station'),
            ),
          ],
        ),
      ),
    );
  }
}
