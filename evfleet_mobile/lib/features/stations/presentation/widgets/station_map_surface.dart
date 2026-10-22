import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/geo_location.dart';
import '../../domain/station.dart';

/// Map abstraction.
///
/// Screens only depend on [StationMapView]. Today it renders
/// [DemoMapSurface] — a lightweight preview surface that needs no API key.
/// To use a real provider, implement a `GoogleMapsSurface` with
/// `google_maps_flutter` (API key in Android/iOS config) and return it from
/// [StationMapView] instead; no screen code has to change.
class StationMapView extends StatelessWidget {
  const StationMapView({
    super.key,
    required this.stations,
    this.selectedId,
    this.onMarkerTap,
    this.center,
  });

  final List<Station> stations;
  final String? selectedId;
  final ValueChanged<Station>? onMarkerTap;
  final GeoLocation? center;

  @override
  Widget build(BuildContext context) {
    return DemoMapSurface(
      stations: stations,
      selectedId: selectedId,
      onMarkerTap: onMarkerTap,
      center: center,
    );
  }
}

/// Key-less preview map: soft terrain, roads, water and positioned markers.
class DemoMapSurface extends StatelessWidget {
  const DemoMapSurface({
    super.key,
    required this.stations,
    this.selectedId,
    this.onMarkerTap,
    this.center,
  });

  final List<Station> stations;
  final String? selectedId;
  final ValueChanged<Station>? onMarkerTap;
  final GeoLocation? center;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final points = <(String, GeoLocation)>[
          for (final station in stations)
            (
              station.id,
              GeoLocation(
                latitude: station.latitude,
                longitude: station.longitude,
              ),
            ),
          if (center != null) ('__center', center!),
        ];

        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const CustomPaint(painter: _TerrainPainter()),
              if (points.isNotEmpty) ..._markers(size, points, context),
              const Positioned(
                left: AppSpacing.md,
                bottom: AppSpacing.sm,
                child: _SurfaceCaption(),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _markers(
    Size size,
    List<(String, GeoLocation)> points,
    BuildContext context,
  ) {
    const pad = 44.0;
    final lats = points.map((p) => p.$2.latitude).toList();
    final lngs = points.map((p) => p.$2.longitude).toList();

    var minLat = lats.reduce((a, b) => a < b ? a : b);
    var maxLat = lats.reduce((a, b) => a > b ? a : b);
    var minLng = lngs.reduce((a, b) => a < b ? a : b);
    var maxLng = lngs.reduce((a, b) => a > b ? a : b);

    // Avoid division by zero when all points coincide.
    if ((maxLat - minLat).abs() < 0.001) {
      minLat -= 0.002;
      maxLat += 0.002;
    }
    if ((maxLng - minLng).abs() < 0.001) {
      minLng -= 0.002;
      maxLng += 0.002;
    }

    Offset positionOf(GeoLocation point) {
      final dx = ((point.longitude - minLng) / (maxLng - minLng)).clamp(
        0.0,
        1.0,
      );
      final dy =
          1 - ((point.latitude - minLat) / (maxLat - minLat)).clamp(0.0, 1.0);
      return Offset(
        pad + dx * (size.width - pad * 2),
        pad + dy * (size.height - pad * 2),
      );
    }

    final stationById = {for (final s in stations) s.id: s};

    return [
      for (final (id, point) in points)
        if (id != '__center')
          Positioned(
            left: positionOf(point).dx - 26,
            top: positionOf(point).dy - 26,
            child: _MarkerPill(
              station: stationById[id]!,
              selected: id == selectedId,
              onTap: onMarkerTap == null
                  ? null
                  : () => onMarkerTap!(stationById[id]!),
            ),
          ),
    ];
  }
}

class _MarkerPill extends StatelessWidget {
  const _MarkerPill({
    required this.station,
    required this.selected,
    this.onTap,
  });

  final Station station;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final available = station.status == AvailabilityStatus.available;
    final background = selected
        ? AppColors.brandDark
        : available
        ? AppColors.brand
        : AppColors.inkSoft;

    return Tooltip(
      message: station.name,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: selected ? 10 : 7,
            vertical: selected ? 8 : 6,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded, color: AppColors.lime, size: 16),
              const SizedBox(width: 4),
              Text(
                Formatters.power(station.chargingPowerKw),
                style: AppTextStyles.badge.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SurfaceCaption extends StatelessWidget {
  const _SurfaceCaption();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'Preview surface — swap in Google Maps via StationMapView',
        style: AppTextStyles.badge.copyWith(color: AppColors.inkSoft),
      ),
    );
  }
}

/// Soft terrain: land wash, a river band and a road grid.
class _TerrainPainter extends CustomPainter {
  const _TerrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final land = Paint()..color = AppColors.mapLand;
    canvas.drawRect(Offset.zero & size, land);

    final water = Paint()..color = AppColors.mapWater;
    final river = Path()
      ..moveTo(-10, size.height * 0.72)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.58,
        size.width * 0.55,
        size.height * 0.86,
        size.width + 10,
        size.height * 0.62,
      )
      ..lineTo(size.width + 10, size.height * 0.74)
      ..cubicTo(
        size.width * 0.55,
        size.height * 0.96,
        size.width * 0.25,
        size.height * 0.7,
        -10,
        size.height * 0.84,
      )
      ..close();
    canvas.drawPath(river, water);

    final road = Paint()
      ..color = AppColors.mapRoad
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final roadMinor = Paint()
      ..color = AppColors.mapRoad.withValues(alpha: 0.75)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    final gridStep = (size.shortestSide / 4).clamp(48.0, 140.0);
    for (var x = gridStep; x < size.width; x += gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), roadMinor);
    }
    for (var y = gridStep; y < size.height; y += gridStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), roadMinor);
    }

    canvas.drawLine(
      Offset(0, size.height * 0.34),
      Offset(size.width, size.height * 0.28),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.18, 0),
      Offset(size.width * 0.32, size.height),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.7, 0),
      Offset(size.width * 0.6, size.height),
      road,
    );

    // A few "blocks" so the surface reads as a city map.
    final block = Paint()..color = AppColors.border.withValues(alpha: 0.55);
    const blockSize = 34.0;
    var seed = 7;
    for (var i = 0; i < 26; i++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      final x = (seed % 1000) / 1000 * size.width;
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      final y = (seed % 1000) / 1000 * size.height;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, blockSize, blockSize * 0.7),
          const Radius.circular(6),
        ),
        block,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TerrainPainter oldDelegate) => false;
}
