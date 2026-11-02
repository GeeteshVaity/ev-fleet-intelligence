
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class StationDetailsData {
  const StationDetailsData({
    required this.id,
    required this.stationName,
    required this.providerType,
    required this.accessType,
    required this.address,
    required this.connectorType,
    required this.powerKw,
    required this.pricePerKwh,
    required this.isActive,
  });

  final String id;
  final String stationName;
  final String providerType;
  final String accessType;
  final String address;
  final String connectorType;
  final double powerKw;
  final double pricePerKwh;
  final bool isActive;
}

class StationDetailsScreen extends StatelessWidget {
  const StationDetailsScreen({
    super.key,
    required this.station,
    required this.onBack,
    required this.onEditStation,
    required this.onManageAvailability,
    required this.onViewBookings,
    required this.onSetActive,
    this.isUpdatingStatus = false,
  });

  final StationDetailsData station;
  final VoidCallback onBack;
  final VoidCallback onEditStation;
  final VoidCallback onManageAvailability;
  final VoidCallback onViewBookings;
  final ValueChanged<bool> onSetActive;
  final bool isUpdatingStatus;

  Future<void> _confirmStatusChange(BuildContext context) async {
    final shouldChange = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            station.isActive ? 'Deactivate Station?' : 'Activate Station?',
          ),
          content: Text(
            station.isActive
                ? 'This station will no longer be available for new bookings. '
                    'Are you sure you want to deactivate it?'
                : 'This station will become active and available for '
                    'bookings according to its availability settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(station.isActive ? 'Deactivate' : 'Activate'),
            ),
          ],
        );
      },
    );

    if (shouldChange == true) {
      onSetActive(!station.isActive);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final statusColor =
        station.isActive ? AppColors.success : AppColors.neutral500;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Station Details'),
        actions: [
          IconButton(
            onPressed: onEditStation,
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit station',
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Station identity
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            height: 52,
                            width: 52,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.ev_station_rounded,
                              color: AppColors.secondary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  station.stationName,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Station ID: ${station.id}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _InfoBadge(
                            label: station.isActive ? 'Active' : 'Inactive',
                            color: statusColor,
                          ),
                          _InfoBadge(
                            label: station.providerType,
                            color: colors.secondary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // Location
              _SectionHeading(title: 'Location'),

              const SizedBox(height: 10),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 42,
                        width: 42,
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.location_on_outlined,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Station Address',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              station.address,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // Technical details
              _SectionHeading(title: 'Charging Specifications'),

              const SizedBox(height: 10),

              Card(
                child: Column(
                  children: [
                    _DetailRow(
                      icon: Icons.electrical_services_rounded,
                      label: 'Connector Type',
                      value: station.connectorType,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _DetailRow(
                      icon: Icons.bolt_rounded,
                      label: 'Power Capacity',
                      value: '${station.powerKw} kW',
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _DetailRow(
                      icon: Icons.currency_rupee_rounded,
                      label: 'Price per kWh',
                      value:
                          '₹${station.pricePerKwh.toStringAsFixed(2)}',
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _DetailRow(
                      icon: Icons.lock_open_rounded,
                      label: 'Access Type',
                      value: station.accessType,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _DetailRow(
                      icon: Icons.business_outlined,
                      label: 'Provider Type',
                      value: station.providerType,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Station management
              _SectionHeading(title: 'Station Management'),

              const SizedBox(height: 10),

              Card(
                child: Column(
                  children: [
                    _ActionTile(
                      icon: Icons.edit_outlined,
                      title: 'Edit Station',
                      subtitle: 'Update station information',
                      onTap: onEditStation,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _ActionTile(
                      icon: Icons.schedule_rounded,
                      title: 'Manage Availability',
                      subtitle: 'Set and manage available time windows',
                      onTap: onManageAvailability,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _ActionTile(
                      icon: Icons.calendar_month_outlined,
                      title: 'View Station Bookings',
                      subtitle: 'Review and manage booking requests',
                      onTap: onViewBookings,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Activate / deactivate
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: isUpdatingStatus
                      ? null
                      : () => _confirmStatusChange(context),
                  icon: isUpdatingStatus
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          station.isActive
                              ? Icons.power_settings_new_rounded
                              : Icons.check_circle_outline_rounded,
                        ),
                  label: Text(
                    isUpdatingStatus
                        ? 'Updating...'
                        : station.isActive
                            ? 'Deactivate Station'
                            : 'Activate Station',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: station.isActive
                        ? colors.error
                        : AppColors.success,
                    side: BorderSide(
                      color: station.isActive
                          ? colors.error
                          : AppColors.success,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------
// Section heading
// --------------------------------------------------

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

// --------------------------------------------------
// Information badge
// --------------------------------------------------

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
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
// Specification row
// --------------------------------------------------

class _DetailRow extends StatelessWidget {
  const _DetailRow({
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

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: colors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------
// Management action tile
// --------------------------------------------------

class _ActionTile extends StatelessWidget {
  const _ActionTile({
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      leading: Icon(
        icon,
        color: colors.primary,
      ),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
      ),
    );
  }
}
