import 'dart:math' as math;

/// A geographic coordinate with an optional human label (city, address...).
///
/// Pure Dart so the distance logic can be unit-tested without platform
/// channels.
class GeoLocation {
  const GeoLocation({
    required this.latitude,
    required this.longitude,
    this.label,
  });

  final double latitude;
  final double longitude;

  /// Free-text label shown next to the location selector (manual fallback).
  final String? label;

  GeoLocation copyWith({double? latitude, double? longitude, String? label}) {
    return GeoLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      label: label ?? this.label,
    );
  }

  /// Great-circle distance in metres between two coordinates.
  static double distanceMeters(GeoLocation a, GeoLocation b) {
    const earthRadius = 6371000.0;
    final lat1 = _rad(a.latitude);
    final lat2 = _rad(b.latitude);
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);

    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLng / 2), 2);
    return 2 * earthRadius * math.asin(math.sqrt(h.clamp(0.0, 1.0)));
  }

  static double _rad(double degrees) => degrees * math.pi / 180;

  @override
  bool operator ==(Object other) =>
      other is GeoLocation &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.label == label;

  @override
  int get hashCode => Object.hash(latitude, longitude, label);

  @override
  String toString() =>
      'GeoLocation(lat: $latitude, lng: $longitude, label: $label)';
}
