
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class BookingDetailsData {
  const BookingDetailsData({
    required this.id,
    required this.status,
    required this.stationName,
    required this.stationAddress,
    required this.connectorType,
    required this.powerKw,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    required this.estimatedCost,
    this.vehicleDetails,
    this.vehicleId,
    this.isSessionStarted = false,
    this.sessionStatus,
    this.finalCost,
    this.energyConsumedKwh,
  });

  final String id;
  final String status;

  final String stationName;
  final String stationAddress;
  final String connectorType;
  final double powerKw;

  final String bookingDate;
  final String startTime;
  final String endTime;
  final double estimatedCost;

  final String? vehicleDetails;
  final String? vehicleId;
  final bool isSessionStarted;
  final String? sessionStatus;
  final double? finalCost;
  final double? energyConsumedKwh;
}

class BookingDetailsScreen extends StatelessWidget {
  const BookingDetailsScreen({
    super.key,
    required this.booking,
    required this.onBack,
    required this.onConfirmBooking,
    required this.onRejectBooking,
    required this.onStartSession,
    this.isProcessing = false,
  });

  final BookingDetailsData booking;

  final VoidCallback onBack;
  final VoidCallback onConfirmBooking;
  final VoidCallback onRejectBooking;
  final VoidCallback onStartSession;

  final bool isProcessing;

  bool get _isPending =>
      booking.status.toUpperCase() == 'PENDING';

  bool get _isConfirmed =>
      booking.status.toUpperCase() == 'CONFIRMED';

  bool get _isSessionCompleted =>
    booking.sessionStatus?.toUpperCase() == 'COMPLETED';

  bool get _isSessionInProgress =>
    booking.isSessionStarted ||
    booking.sessionStatus?.toUpperCase() == 'IN_PROGRESS';

  Color _statusColor() {
    switch (booking.status.toUpperCase()) {
      case 'PENDING':
        return AppColors.warning;
      case 'CONFIRMED':
        return AppColors.success;
      case 'REJECTED':
      case 'CANCELLED':
        return AppColors.error;
      default:
        return AppColors.neutral500;
    }
  }

  Future<void> _confirmAction({
    required BuildContext context,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onConfirm,
    bool destructive = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: destructive
                  ? ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor:
                          Theme.of(context).colorScheme.onError,
                    )
                  : null,
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      onConfirm();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final statusColor = _statusColor();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Booking Details'),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Booking identity
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        height: 46,
                        width: 46,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.calendar_month_rounded,
                          color: AppColors.secondary,
                          size: 25,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BOOKING #${booking.id}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.onSurfaceVariant,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Station Booking',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
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
                ),
              ),

              const SizedBox(height: 22),

              // Station information
              _SectionHeading(title: 'Charging Station'),

              const SizedBox(height: 10),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.ev_station_rounded,
                              color: colors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              booking.stationName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      _InfoRow(
                        icon: Icons.location_on_outlined,
                        label: booking.stationAddress,
                      ),

                      const Divider(height: 24),

                      _InfoRow(
                        icon: Icons.electrical_services_rounded,
                        label: 'Connector: ${booking.connectorType}',
                      ),

                      const SizedBox(height: 10),

                      _InfoRow(
                        icon: Icons.bolt_rounded,
                        label: 'Power capacity: ${booking.powerKw} kW',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // Vehicle information
              if (booking.vehicleDetails != null &&
                  booking.vehicleDetails!.isNotEmpty) ...[
                _SectionHeading(title: 'Vehicle Details'),

                const SizedBox(height: 10),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          height: 44,
                          width: 44,
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.directions_car_outlined,
                            color: colors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                booking.vehicleDetails!,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (booking.vehicleId != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Vehicle ID: ${booking.vehicleId}',
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
                  ),
                ),

                const SizedBox(height: 22),
              ],

              // Booking schedule
              _SectionHeading(title: 'Booking Schedule'),

              const SizedBox(height: 10),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.calendar_today_outlined,
                        label: booking.bookingDate,
                      ),

                      const Divider(height: 24),

                      _InfoRow(
                        icon: Icons.access_time_rounded,
                        label:
                            '${booking.startTime} – ${booking.endTime}',
                      ),

                      const Divider(height: 24),

                      _InfoRow(
                        icon: Icons.timelapse_rounded,
                        label: 'Reserved charging time',
                        value: _durationLabel(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // Estimated cost
              _SectionHeading(title: 'Booking Cost'),

              const SizedBox(height: 10),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Estimated Cost',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Text(
                            '₹${booking.estimatedCost.toStringAsFixed(2)}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      if (_isSessionCompleted) ...[
                        const Divider(height: 24),

                        if (booking.energyConsumedKwh != null)
                          _InfoRow(
                            icon: Icons.bolt_rounded,
                            label: 'Energy Consumed',
                            value: '${booking.energyConsumedKwh!.toStringAsFixed(2)} kWh',
                          ),

                        if (booking.finalCost != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Final Bill',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                '₹${booking.finalCost!.toStringAsFixed(2)}',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ] else ...[
                        const SizedBox(height: 8),
                        Text(
                          'Final cost may differ based on the completed charging session.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Pending booking actions
              if (_isPending) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: isProcessing
                        ? null
                        : () => _confirmAction(
                              context: context,
                              title: 'Confirm Booking?',
                              message:
                                  'Confirm this booking request for '
                                  '${booking.stationName}?',
                              actionLabel: 'Confirm Booking',
                              onConfirm: onConfirmBooking,
                            ),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Confirm Booking'),
                  ),
                ),

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: isProcessing
                        ? null
                        : () => _confirmAction(
                              context: context,
                              title: 'Reject Booking?',
                              message:
                                  'Are you sure you want to reject '
                                  'this booking request?',
                              actionLabel: 'Reject Booking',
                              destructive: true,
                              onConfirm: onRejectBooking,
                            ),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject Booking'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                      side: BorderSide(color: colors.error),
                    ),
                  ),
                ),
              ],

              // Confirmed booking action
              if (_isConfirmed && !_isSessionCompleted)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: isProcessing
                        ? null
                        : () => _confirmAction(
                              context: context,
                              title: _isSessionInProgress
                                  ? 'Complete Charging Session?'
                                  : 'Start Charging Session?',
                              message: _isSessionInProgress
                                  ? 'Are you sure you want to complete this charging session?'
                                  : 'Start a charging session for this confirmed booking?',
                              actionLabel: _isSessionInProgress
                                  ? 'Complete Session'
                                  : 'Start Session',
                              onConfirm: onStartSession,
                            ),
                    icon: Icon(
                      _isSessionInProgress
                          ? Icons.stop_circle_outlined
                          : Icons.bolt_rounded,
                    ),
                    label: Text(
                      _isSessionInProgress
                          ? 'Complete Charging Session'
                          : 'Start Charging Session',
                    ),
                  ),
                ),

                // Completed charging session
                if (_isSessionCompleted)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Charging Session Completed',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'This charging session has been completed. '
                          'No further session actions are available.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

              // Terminal booking status
              if (!_isPending && !_isConfirmed && !_isSessionCompleted)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'This booking is ${booking.status.toLowerCase()}. '
                    'No further booking actions are available.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),

              if (isProcessing) ...[
                const SizedBox(height: 16),
                const Center(
                  child: CircularProgressIndicator(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _durationLabel() {
    final start = _parseTime(booking.startTime);
    final end = _parseTime(booking.endTime);

    if (start == null || end == null) {
      return '—';
    }

    final minutes = end - start;

    if (minutes <= 0) {
      return '—';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours == 0) {
      return '$remainingMinutes min';
    }

    if (remainingMinutes == 0) {
      return '$hours hr';
    }

    return '$hours hr $remainingMinutes min';
  }

  int? _parseTime(String value) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$',
      caseSensitive: false,
    ).firstMatch(value.trim());

    if (match == null) return null;

    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3)?.toUpperCase();

    if (hour > 23 || minute > 59) return null;

    if (period != null) {
      if (hour < 1 || hour > 12) return null;
      if (period == 'AM' && hour == 12) hour = 0;
      if (period == 'PM' && hour != 12) hour += 12;
    }

    return hour * 60 + minute;
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
// Information row
// --------------------------------------------------

class _InfoRow extends StatelessWidget {
  const _InfoRow({
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
          size: 19,
          color: colors.primary,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        if (value != null)
          Text(
            value!,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

// --------------------------------------------------
// Status badge
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
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
