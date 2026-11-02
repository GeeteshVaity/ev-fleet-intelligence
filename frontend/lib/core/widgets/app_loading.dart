import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';

/// Centered spinner with an optional label, used while a provider is loading.
class AppLoading extends StatelessWidget {
  const AppLoading({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            if (label != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(label!, style: AppTextStyles.bodySoft),
            ],
          ],
        ),
      ),
    );
  }
}

/// Inline linear progress used inside list headers / buttons areas.
class AppInlineProgress extends StatelessWidget {
  const AppInlineProgress({super.key});

  @override
  Widget build(BuildContext context) {
    return const LinearProgressIndicator(
      color: AppColors.brand,
      backgroundColor: AppColors.brandSoft,
      minHeight: 3,
    );
  }
}

/// Skeleton placeholder block used while card content is loading.
class AppSkeletonBox extends StatelessWidget {
  const AppSkeletonBox({
    super.key,
    this.height = 16,
    this.width,
    this.radius = AppSpacing.radiusSm,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.neutralSoft,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
