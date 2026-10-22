import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../features/bookings/domain/booking.dart';

/// Pill badge used for booking statuses, availability and generic tags.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.foreground,
    required this.background,
    this.icon,
  });

  final String label;
  final Color foreground;
  final Color background;
  final IconData? icon;

  /// Booking-status badge with the design-system colours per status.
  factory StatusBadge.forBookingStatus(BookingStatus status) {
    final (color, soft, icon) = switch (status) {
      BookingStatus.pending => (
        AppColors.warning,
        AppColors.warningSoft,
        Icons.hourglass_top_rounded,
      ),
      BookingStatus.confirmed => (
        AppColors.success,
        AppColors.successSoft,
        Icons.check_circle_rounded,
      ),
      BookingStatus.rejected => (
        AppColors.danger,
        AppColors.dangerSoft,
        Icons.cancel_rounded,
      ),
      BookingStatus.cancelled => (
        AppColors.inkSoft,
        AppColors.neutralSoft,
        Icons.block_rounded,
      ),
      BookingStatus.completed => (
        AppColors.brand,
        AppColors.brandSoft,
        Icons.bolt_rounded,
      ),
    };
    return StatusBadge(
      label: status.label,
      foreground: color,
      background: soft,
      icon: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 5),
          ],
          Text(label, style: AppTextStyles.badge.copyWith(color: foreground)),
        ],
      ),
    );
  }
}

/// Generic small tag (connector type, provider type, kW...).
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    this.icon,
    this.foreground = AppColors.inkSoft,
    this.background = AppColors.neutralSoft,
  });

  final String label;
  final IconData? icon;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(label, style: AppTextStyles.badge.copyWith(color: foreground)),
        ],
      ),
    );
  }
}
