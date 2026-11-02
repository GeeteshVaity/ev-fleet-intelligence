import 'package:geolocator/geolocator.dart';

import '../../shared/models/geo_location.dart';

/// Outcome of a device-location request. The failure reason is preserved so
/// the UI can offer a manual search fallback instead of failing silently.
enum LocationStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
  unavailable,
}

class LocationResult {
  const LocationResult(this.status, {this.location});

  final LocationStatus status;
  final GeoLocation? location;

  bool get hasLocation => location != null;
}

/// Thin wrapper around Geolocator so screens never talk to platform channels
/// directly and tests can substitute a fake.
class LocationService {
  const LocationService();

  Future<LocationResult> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationResult(LocationStatus.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      switch (permission) {
        case LocationPermission.denied:
          return const LocationResult(LocationStatus.denied);
        case LocationPermission.deniedForever:
          return const LocationResult(LocationStatus.deniedForever);
        case LocationPermission.unableToDetermine:
          return const LocationResult(LocationStatus.unavailable);
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          break;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return LocationResult(
        LocationStatus.granted,
        location: GeoLocation(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
    } catch (_) {
      return const LocationResult(LocationStatus.unavailable);
    }
  }
}
