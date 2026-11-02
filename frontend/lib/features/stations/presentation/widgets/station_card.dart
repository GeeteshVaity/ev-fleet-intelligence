import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/station.dart';

/// The canonical station card: image, name, distance, power, connector,
/// price and availability — rating only when real rating data exists.
class StationCard extends StatelessWidget {
  const StationCard({
    super.key,
    required this.station,
    this.onTap,
    this.trailing,
    this.compact = false,
  });

  final Station station;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final station = this.station;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!compact) _StationImage(station: station),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              station.name,
                              style: AppTextStyles.cardTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              station.address,
                              style: AppTextStyles.meta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _AvailabilityDot(status: station.status),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _MetaChip(
                        icon: Icons.bolt_rounded,
                        label: Formatters.power(station.chargingPowerKw),
                        accent: true,
                      ),
                      _MetaChip(
                        icon: station.connectorType == ConnectorType.ccs2
                            ? Icons.ev_plug_ccs2_rounded
                            : Icons.ev_plug_type2_rounded,
                        label: station.connectorType.label,
                      ),
                      _MetaChip(
                        icon: Icons.payments_outlined,
                        label: Formatters.price(
                          station.pricePerKwh,
                          currency: _currencySymbol(station.currency),
                        ),
                      ),
                      if (station.distanceMeters != null)
                        _MetaChip(
                          icon: Icons.near_me_outlined,
                          label: Formatters.distance(station.distanceMeters),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      if (station.hasRatings) ...[
                        const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          Formatters.rating(station.rating!),
                          style: AppTextStyles.badge,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '(${station.ratingCount})',
                          style: AppTextStyles.meta,
                        ),
                        const Spacer(),
                      ] else
                        const Spacer(),
                      if (trailing != null) trailing!,
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _currencySymbol(String code) => switch (code) {
    'EUR' => '€',
    'USD' => r'$',
    'GBP' => '£',
    _ => '$code ',
  };
}

class _StationImage extends StatelessWidget {
  const _StationImage({required this.station});

  final Station station;

  @override
  Widget build(BuildContext context) {
    final url = station.imageUrls.isNotEmpty ? station.imageUrls.first : null;

    return SizedBox(
      height: 148,
      width: double.infinity,
      child: url == null
          ? const _ImagePlaceholder()
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (context, url) => const _ImagePlaceholder(),
              errorWidget: (context, url, error) => const _ImagePlaceholder(),
            ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.brandSoft,
      alignment: Alignment.center,
      child: const Icon(
        Icons.ev_station_rounded,
        size: 42,
        color: AppColors.brand,
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ? AppColors.brand : AppColors.inkSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: accent ? AppColors.brandSoft : AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: accent
              ? AppColors.brand.withValues(alpha: 0.25)
              : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.badge.copyWith(
              color: accent ? AppColors.brandDark : AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityDot extends StatelessWidget {
  const _AvailabilityDot({required this.status});

  final AvailabilityStatus status;

  ({Color color, String label}) get _style => switch (status) {
    AvailabilityStatus.available => (
      color: AppColors.success,
      label: 'Available',
    ),
    AvailabilityStatus.busy => (color: AppColors.warning, label: 'In use'),
    AvailabilityStatus.offline => (color: AppColors.danger, label: 'Offline'),
    AvailabilityStatus.unknown => (color: AppColors.inkMuted, label: 'Unknown'),
  };

  @override
  Widget build(BuildContext context) {
    final style = _style;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: style.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            style.label,
            style: AppTextStyles.badge.copyWith(color: style.color),
          ),
        ],
      ),
    );
  }
}
