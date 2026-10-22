import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../presentation/providers/auth_provider.dart';

/// Shared layout for the auth screens: brand header, scrollable card content
/// and the development-only "demo auth" badge when applicable.
class AuthScaffold extends ConsumerWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showDemoBadge = true,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool showDemoBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMockAuth = ref.watch(authIsMockProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.lg,
              AppSpacing.screenPadding,
              AppSpacing.xxl,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _BrandMark(),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(title, style: AppTextStyles.screenTitle),
                  const SizedBox(height: AppSpacing.sm),
                  Text(subtitle, style: AppTextStyles.bodySoft),
                  if (showDemoBadge && isMockAuth) ...[
                    const SizedBox(height: AppSpacing.md),
                    const _MockAuthBanner(),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: const Icon(Icons.bolt_rounded, color: AppColors.lime),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          'EV Fleet',
          style: AppTextStyles.sectionTitle.copyWith(
            color: AppColors.brandDark,
            fontSize: 18,
          ),
        ),
      ],
    );
  }
}

/// Explicit, impossible-to-miss label: authentication here is a mock.
class _MockAuthBanner extends StatelessWidget {
  const _MockAuthBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.science_outlined, size: 18, color: AppColors.warning),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Development-only demo authentication. Amazon Cognito is not '
              'connected yet — see the README checklist before shipping.',
              style: AppTextStyles.meta,
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline error/info text used by the auth forms.
class AuthFeedback extends StatelessWidget {
  const AuthFeedback({super.key, this.error, this.info});

  final String? error;
  final String? info;

  @override
  Widget build(BuildContext context) {
    if (error == null && info == null) return const SizedBox.shrink();

    final isError = error != null;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Container(
        key: ValueKey('${error ?? ''}|${info ?? ''}'),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isError ? AppColors.dangerSoft : AppColors.infoSoft,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: (isError ? AppColors.danger : AppColors.info).withValues(
              alpha: 0.3,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.info_outline_rounded,
              size: 18,
              color: isError ? AppColors.danger : AppColors.info,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                error ?? info!,
                style: AppTextStyles.meta.copyWith(
                  color: isError ? AppColors.danger : AppColors.info,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
