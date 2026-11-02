import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';

enum AppButtonVariant { primary, secondary, ghost, danger }

/// The one button used across the app: primary/secondary/ghost/danger
/// variants, optional loading state and an accessible 52px touch target.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool loading;

  /// When true the button stretches to the available width.
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !loading;
    final child = loading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: _spinnerColor,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    final ButtonStyle style = switch (variant) {
      AppButtonVariant.primary => FilledButton.styleFrom(
        backgroundColor: AppColors.brand,
        foregroundColor: AppColors.onBrand,
        disabledBackgroundColor: AppColors.neutralSoft,
        disabledForegroundColor: AppColors.inkMuted,
      ),
      AppButtonVariant.secondary => FilledButton.styleFrom(
        backgroundColor: AppColors.brandSoft,
        foregroundColor: AppColors.brandDark,
        disabledBackgroundColor: AppColors.neutralSoft,
        disabledForegroundColor: AppColors.inkMuted,
      ),
      AppButtonVariant.ghost => FilledButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.brand,
        disabledForegroundColor: AppColors.inkMuted,
      ),
      AppButtonVariant.danger => FilledButton.styleFrom(
        backgroundColor: AppColors.danger,
        foregroundColor: AppColors.onBrand,
        disabledBackgroundColor: AppColors.neutralSoft,
        disabledForegroundColor: AppColors.inkMuted,
      ),
    };

    return FilledButton(
      onPressed: isEnabled ? onPressed : null,
      style: style,
      child: SizedBox(
        width: expanded ? double.infinity : null,
        child: DefaultTextStyle(
          style: AppTextStyles.button.copyWith(
            color: isEnabled ? null : AppColors.inkMuted,
          ),
          child: child,
        ),
      ),
    );
  }

  Color? get _spinnerColor => switch (variant) {
    AppButtonVariant.primary => AppColors.onBrand,
    AppButtonVariant.danger => AppColors.onBrand,
    AppButtonVariant.secondary => AppColors.brandDark,
    AppButtonVariant.ghost => AppColors.brand,
  };
}
