
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

class ChargingSessionData {
  const ChargingSessionData({
    required this.id,
    required this.status,
    required this.bookingId,
    required this.stationName,
    required this.startTime,
    this.actualEndTime,
    this.energyConsumedKwh,
    this.finalCost,
  });

  final String id;
  final String status;
  final String bookingId;
  final String stationName;
  final String startTime;
  final String? actualEndTime;
  final double? energyConsumedKwh;
  final double? finalCost;
}

class ChargingSessionDetailsScreen extends StatefulWidget {
  const ChargingSessionDetailsScreen({
    super.key,
    required this.session,
    required this.onBack,
    required this.onOpenBooking,
    required this.onCompleteSession,
    this.isProcessing = false,
  });

  final ChargingSessionData session;

  final VoidCallback onBack;
  final VoidCallback onOpenBooking;
  final ValueChanged<double> onCompleteSession;

  final bool isProcessing;

  @override
  State<ChargingSessionDetailsScreen> createState() =>
      _ChargingSessionDetailsScreenState();
}

class _ChargingSessionDetailsScreenState
    extends State<ChargingSessionDetailsScreen> {
  final _energyController = TextEditingController();

  bool get _isInProgress =>
      widget.session.status.toUpperCase() == 'IN_PROGRESS';

  bool get _isCompleted =>
      widget.session.status.toUpperCase() == 'COMPLETED';

  Color _statusColor() {
    switch (widget.session.status.toUpperCase()) {
      case 'IN_PROGRESS':
        return AppColors.success;
      case 'COMPLETED':
        return AppColors.secondary;
      default:
        return AppColors.neutral500;
    }
  }

  @override
  void dispose() {
    _energyController.dispose();
    super.dispose();
  }

  Future<void> _completeSession() async {
    final energy = double.tryParse(_energyController.text.trim());

    if (energy == null || !energy.isFinite || energy < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid non-negative energy value.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Complete Charging Session?'),
          content: Text(
            'Submit ${energy.toStringAsFixed(2)} kWh as the '
            'energy consumed for this session?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              child: const Text('Complete Session'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      widget.onCompleteSession(energy);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final session = widget.session;
    final statusColor = _statusColor();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Charging Session'),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Session identity
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                              Icons.bolt_rounded,
                              color: AppColors.secondary,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SESSION ID',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  session.id,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isCompleted
                                  ? Icons.check_circle_rounded
                                  : _isInProgress
                                      ? Icons.bolt_rounded
                                      : Icons.info_outline_rounded,
                              size: 15,
                              color: statusColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              session.status.replaceAll('_', ' '),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
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
                            height: 42,
                            width: 42,
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.ev_station_rounded,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              session.stationName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _InfoRow(
                        icon: Icons.calendar_month_outlined,
                        label: 'Booking ID',
                        value: session.bookingId,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: widget.onOpenBooking,
                          child: const Text('View Associated Booking'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // Session timing
              _SectionHeading(title: 'Session Timing'),

              const SizedBox(height: 10),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.play_circle_outline_rounded,
                        label: 'Session Started',
                        value: session.startTime,
                      ),
                      const Divider(height: 24),
                      _InfoRow(
                        icon: Icons.stop_circle_outlined,
                        label: 'Session Ended',
                        value: session.actualEndTime ?? 'Not completed',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // Energy information
              _SectionHeading(title: 'Energy Consumption'),

              const SizedBox(height: 10),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Energy Consumed',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            session.energyConsumedKwh == null
                                ? '—'
                                : session.energyConsumedKwh!
                                    .toStringAsFixed(2),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Text(
                              'kWh',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (_isInProgress) ...[
                        const SizedBox(height: 18),
                        Text(
                          'Enter final energy consumed',
                          style: theme.textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _energyController,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            hintText: 'Enter energy in kWh',
                            prefixIcon: Icon(Icons.bolt_rounded),
                            suffixText: 'kWh',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Use the actual measured energy value from '
                          'your charging process.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // Final cost
              _SectionHeading(title: 'Session Cost'),

              const SizedBox(height: 10),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.currency_rupee_rounded,
                        label: 'Final Cost',
                        value: session.finalCost == null
                            ? 'Available after completion'
                            : '₹${session.finalCost!.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 12),
                      if (!_isCompleted)
                        Text(
                          'The final session cost will be provided '
                          'by the backend after completion.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Complete session
              if (_isInProgress)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: widget.isProcessing
                        ? null
                        : _completeSession,
                    icon: widget.isProcessing
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.black,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline_rounded),
                    label: Text(
                      widget.isProcessing
                          ? 'Completing Session...'
                          : 'Complete Charging Session',
                    ),
                  ),
                ),

              if (_isCompleted)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                      ),
                      SizedBox(width: 9),
                      Text(
                        'Charging Session Completed',
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
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
// Information row
// --------------------------------------------------

class _InfoRow extends StatelessWidget {
  const _InfoRow({
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
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
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
    );
  }
}
