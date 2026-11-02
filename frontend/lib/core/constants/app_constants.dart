import '../../shared/models/geo_location.dart';

/// Application-wide, non-secret constants.
abstract final class AppConstants {
  static const String appName = 'EV Fleet';
  static const String appTagline = 'Find, book and charge — anywhere.';

  /// Latency added by mock repositories so loading states are visible.
  static const Duration mockLatency = Duration(milliseconds: 350);

  /// Timeout used by the Dio client for future Spring Boot calls.
  static const Duration networkTimeout = Duration(seconds: 20);

  /// How many days ahead the booking flow offers time slots.
  static const int bookingDaysAhead = 7;

  /// Length of each selectable booking slot.
  static const int bookingSlotMinutes = 60;

  /// Longest booking the UI allows in one go.
  static const int maxBookingHours = 4;

  /// Human-readable currency used across the demo dataset.
  static const String currencySymbol = '€';

  /// Development-only demo identity. This is NOT a real account.
  static const String demoEmail = 'demo@evfleet.app';
  static const String demoName = 'Demo Driver';

  /// Verification code accepted by the development-only mock auth flow.
  /// Real verification is handled by Amazon Cognito once configured.
  static const String demoVerificationCode = '123456';

  /// Label shown wherever data comes from the built-in mock repositories.
  static const String demoDataLabel = 'Demo data';

  /// Non-sensitive SharedPreferences keys.
  static const String onboardingSeenKey = 'onboarding.seen';

  /// Minimum splash display time so the first frame never flashes.
  static const Duration splashMinimum = Duration(milliseconds: 700);

  /// Demo search origin (labelled as demo in the UI) so distances render
  /// before real device location is available.
  static const GeoLocation demoOrigin = GeoLocation(
    latitude: 52.5200,
    longitude: 13.4050,
    label: 'Berlin, Mitte (demo)',
  );
}
