import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_section_header.dart';
import '../../domain/station.dart';
import '../providers/station_providers.dart';

/// Filter editor for station discovery: distance, connector, charging speed,
/// price range, availability window and provider type (household/business/
/// public). Edits are staged locally and applied on "Show results".
class StationFiltersScreen extends ConsumerStatefulWidget {
  const StationFiltersScreen({super.key});

  @override
  ConsumerState<StationFiltersScreen> createState() =>
      _StationFiltersScreenState();
}

class _StationFiltersScreenState extends ConsumerState<StationFiltersScreen> {
  late StationFilter _draft;

  static const List<double> _distanceOptions = [1, 2, 5, 10, 25, 50];
  static const List<double> _priceCeilings = [0.30, 0.40, 0.50, 0.60, 0.80];

  @override
  void initState() {
    super.initState();
    _draft = ref.read(stationFilterProvider);
  }

  void _apply() {
    ref.read(stationFilterProvider.notifier).update(_draft);
    context.pop();
  }

  void _resetAll() {
    setState(() => _draft = StationFilter.empty);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filters'),
        actions: [
          TextButton(onPressed: _resetAll, child: const Text('Reset')),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          AppSpacing.sm,
          AppSpacing.screenPadding,
          AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppSectionHeader(
              title: 'Distance',
              subtitle: 'Maximum distance from your location',
              padding: EdgeInsets.only(top: AppSpacing.sm),
            ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final km in _distanceOptions)
                  _SelectableChip(
                    label: '${km.toStringAsFixed(0)} km',
                    selected: _draft.maxDistanceKm == km,
                    onTap: () => setState(() => _draft = _draft.copyWith(
                          maxDistanceKm: km,
                          clearMaxDistance: _draft.maxDistanceKm == km,
                        )),
                  ),
              ],
            ),
            const AppSectionHeader(title: 'Connector type'),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final connector in ConnectorType.values)
                  _SelectableChip(
                    label: connector.label,
                    selected: _draft.connectors.contains(connector),
                    onTap: () => _toggleConnector(connector),
                  ),
              ],
            ),
            const AppSectionHeader(
              title: 'Charging speed',
              subtitle: 'Filter by power output',
            ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final tier in ChargingTier.values)
                  _SelectableChip(
                    label: tier == ChargingTier.slow
                        ? '${tier.label} (<11 kW)'
                        : tier == ChargingTier.standard
                            ? '${tier.label} (11–22 kW)'
                            : tier == ChargingTier.fast
                                ? '${tier.label} (22–100 kW)'
                                : '${tier.label} (100 kW+)',
                    selected: _draft.speedTier == tier,
                    onTap: () => setState(
                      () => _draft = _draft.copyWith(
                        speedTier: tier,
                        clearSpeedTier: _draft.speedTier == tier,
                      ),
                    ),
                  ),
              ],
            ),
            const AppSectionHeader(
              title: 'Price per kWh',
              subtitle: _draft.maxPricePerKwh == null
                  ? 'No maximum selected'
                  : 'Up to €${_draft.maxPricePerKwh!.toStringAsFixed(2)}/kWh',
            ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final price in _priceCeilings)
                  _SelectableChip(
                    label: '≤ €${price.toStringAsFixed(2)}',
                    selected: _draft.maxPricePerKwh == price,
                    onTap: () => setState(() => _draft = _draft.copyWith(
                          maxPricePerKwh: price,
                          clearPriceRange: _draft.maxPricePerKwh == price,
                        )),
              ],
            ),
            const AppSectionHeader(
              title: 'Available time',
              subtitle: 'Show stations open during this window',
            ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final (label, from, to) in _availabilityWindows)
                  _SelectableChip(
                    label: label,
                    selected: _draft.availableFromHour == from &&
                        _draft.availableToHour == to,
                    onTap: () => setState(
                      () => _draft = _draft.copyWith(
                        availableFromHour: from,
                        availableToHour: to,
                        clearAvailabilityWindow: _draft.availableFromHour ==
                                from &&
                            _draft.availableToHour == to,
                      ),
                    ),
                  ),
              ],
            ),
            const AppSectionHeader(
              title: 'Station type',
              subtitle: 'Household, business or public',
            ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final type in StationProviderType.values)
                  _SelectableChip(
                    label: type.label,
                    selected: _draft.providerTypes.contains(type),
                    onTap: () => _toggleProviderType(type),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              label: 'Show results',
              onPressed: _apply,
            ),
          ],
        ),
      ),
    );
  }

  void _toggleConnector(ConnectorType connector) {
    setState(() {
      final next = Set<ConnectorType>.of(_draft.connectors);
      if (next.contains(connector)) {
        next.remove(connector);
      } else {
        next.add(connector);
      }
      _draft = _draft.copyWith(connectors: next);
    });
  }

  void _toggleProviderType(StationProviderType type) {
    setState(() {
      final next = Set<StationProviderType>.of(_draft.providerTypes);
      if (next.contains(type)) {
        next.remove(type);
      } else {
        next.add(type);
      }
      _draft = _draft.copyWith(providerTypes: next);
    });
  }
}

const List<(String, int?, int?)> _availabilityWindows = [
  ('Any time', null, null),
  ('Morning (06–12)', 6, 12),
  ('Afternoon (12–18)', 12, 18),
  ('Evening (18–23)', 18, 23),
  ('Night (22–06)', 22, 6),
];

class _SelectableChip extends StatelessWidget {
  const _SelectableChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.brand : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          border: Border.all(
            color: selected
                ? AppColors.brand
                : AppColors.borderStrong.withValues(alpha: 0.8),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.badge.copyWith(
            color: selected ? Colors.white : AppColors.inkSoft,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
