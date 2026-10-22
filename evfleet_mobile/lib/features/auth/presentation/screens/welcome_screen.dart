import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_button.dart';

/// Landing screen of the auth group: brand, value proposition and the two
/// entry points (sign in / create account).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const List<(IconData, String)> _highlights = [
    (Icons.near_me_outlined, 'Nearby household, business and public chargers'),
    (Icons.schedule_rounded, 'Slot booking with a clear review step'),
    (Icons.receipt_long_outlined, 'History: energy consumed and final cost'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.xl,
            AppSpacing.screenPadding,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: AppColors.lime,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    AppConstants.appName,
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: AppColors.brandDark,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.xxl),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.brandDark, AppColors.brand],
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.ev_station_rounded,
                      color: AppColors.lime,
                      size: 44,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Charge without\nthe guesswork.',
                      style: AppTextStyles.screenTitle.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Discover chargers, book a slot and keep every session '
                      'in one place.',
                      style: AppTextStyles.body.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              for (final (icon, label) in _highlights)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: AppColors.brandSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 18, color: AppColors.brand),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: Text(label, style: AppTextStyles.body)),
                    ],
                  ),
                ),
              const Spacer(),
              AppButton(
                label: 'Create free account',
                onPressed: () => context.push(RoutePaths.signUp),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'I already have an account',
                variant: AppButtonVariant.secondary,
                onPressed: () => context.push(RoutePaths.signIn),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
