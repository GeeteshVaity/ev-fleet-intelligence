import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_section_header.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../domain/station.dart';
import '../providers/station_providers.dart';
import '../widgets/station_card.dart';

/// Station discovery list: search, filter chips, active-filter summary and
/// the explicit loading/empty/error states.
class StationListScreen extends ConsumerWidget {
  const StationListScreen({super.key, this.embedded = false});

  /// When true the screen skips its own Scaffold/AppBar (used by the Explore
  /// tab so the search bar stays pinned).
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stationsAsync = ref.watch(stationsProvider);
    final filter = ref.watch(stationFilterProvider);
    final location = ref.watch(userLocationProvider);

    final body = Column(
      children: [
        _FilterBar(
          filter: filter,
          locationLabel: location.location?.label,
          onFilters: () => context.push(RoutePaths.stationFilters),
          onClear: () => ref.read(stationFilterProvider.notifier).reset(),
        ),
        Expanded(
          child: stationsAsync.when(
            loading: () => const AppLoading(label: 'Finding chargers…'),
            error: (error, _) => AppErrorView(
              message: errorMessageOf(error),
              onRetry: () => ref.invalidate(stationsProvider),
            ),
            data: (stations) => stations.isEmpty
                ? AppEmptyView(
                    icon: Icons.search_off_rounded,
                    title: 'No stations match',
                    message: filter.isActive
                        ? 'Try widening your filters or searching another area.'
                        : 'No chargers are available for this area yet.',
                    actionLabel: filter.isActive ? 'Clear filters' : null,
                    onAction: filter.isActive
                        ? () => ref.read(stationFilterProvider.notifier).reset()
                        : null,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenPadding,
                      AppSpacing.sm,
                      AppSpacing.screenPadding,
                      AppSpacing.xxl,
                    ),
                    itemCount: stations.length + 1,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _ListHeader(
                          count: stations.length,
                          locationLabel: location.location?.label,
                        );
                      }
                      final station = stations[index - 1];
                      return StationCard(
                        station: station,
                        onTap: () =>
                            context.push(RoutePaths.station(station.id)),
                      );
                    },
                  ),
          ),
        ),
      ],
    );

    if (embedded) return body;

    return Scaffold(
      appBar: AppBar(title: const Text('Find chargers')),
      body: body,
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({required this.count, this.locationLabel});

  final int count;
  final String? locationLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: '$count charger${count == 1 ? '' : 's'} found',
          subtitle: locationLabel == null ? null : 'Around $locationLabel',
          padding: const EdgeInsets.only(
            top: AppSpacing.md,
            bottom: AppSpacing.md,
          ),
        ),
        const DemoDataNote(),
      ],
    );
  }
}

/// Small caption that keeps demo data unmistakable.
class DemoDataNote extends ConsumerWidget {
  const DemoDataNote({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMock = ref.watch(isDemoDataProvider);
    if (!isMock) return const SizedBox.shrink();

    return const Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: StatusBadge(
        label: 'Demo data — not from a live backend',
        foreground: AppColors.inkSoft,
        background: AppColors.neutralSoft,
        icon: Icons.info_outline_rounded,
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({
    required this.filter,
    required this.onFilters,
    required this.onClear,
    this.locationLabel,
  });

  final StationFilter filter;
  final VoidCallback onFilters;
  final VoidCallback onClear;
  final String? locationLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chips = <Widget>[
      ActionChip(
        avatar: Icon(
          Icons.tune_rounded,
          size: 16,
          color: filter.isActive ? AppColors.brand : AppColors.inkSoft,
        ),
        label: Text(
          filter.isActive ? 'Filters • ${filter.activeCount}' : 'Filters',
          style: AppTextStyles.badge.copyWith(
            color: filter.isActive ? AppColors.brandDark : AppColors.inkSoft,
          ),
        ),
        onPressed: onFilters,
        backgroundColor: filter.isActive
            ? AppColors.brandSoft
            : AppColors.surface,
        side: BorderSide(
          color: filter.isActive
              ? AppColors.brand.withValues(alpha: 0.4)
              : AppColors.border,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        ),
      ),
      for (final connector in filter.connectors)
        Chip(
          avatar: const Icon(Icons.ev_station_outlined, size: 15),
          label: Text(connector.label, style: AppTextStyles.badge),
          visualDensity: VisualDensity.compact,
          onDeleted: () => ref
              .read(stationFilterProvider.notifier)
              .toggleConnector(connector),
          deleteIcon: const Icon(Icons.close, size: 15),
        ),
      if (filter.isActive)
        TextButton(
          onPressed: onClear,
          child: const Text('Clear all', style: AppTextStyles.badge),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.sm,
        AppSpacing.screenPadding,
        0,
      ),
      child: SizedBox(
        height: 44,
        child: ListView(scrollDirection: Axis.horizontal, children: chips),
      ),
    );
  }
}
