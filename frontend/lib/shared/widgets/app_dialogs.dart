import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';

/// Shows a Material confirmation dialog and resolves to `true` only when the
/// user explicitly confirms. Used for destructive actions (cancel booking,
/// delete vehicle, sign out, delete account).
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Keep',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, style: AppTextStyles.title),
      content: Text(message, style: AppTextStyles.body),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        SizedBox(
          width: 140,
          child: AppButton(
            label: confirmLabel,
            variant: destructive
                ? AppButtonVariant.danger
                : AppButtonVariant.primary,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Small snackbar helper with the product's standard styling.
void showSnackMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Inline "demo/mock" pill used to keep mock behaviour unmistakable.
class DemoTag extends StatelessWidget {
  const DemoTag({super.key, this.label = 'Demo'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.lime.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: AppColors.limeDark.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: AppTextStyles.badge.copyWith(color: AppColors.brandDark),
      ),
    );
  }
}
