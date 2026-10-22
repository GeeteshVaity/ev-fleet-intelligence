/// Every route path/ name in the app, defined once so navigation and guards
/// never drift apart.
abstract final class RoutePaths {
  // --- Onboarding & authentication ---------------------------------------
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String welcome = '/welcome';
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String verifyEmail = '/verify-email';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';

  // --- Main shell (bottom navigation) ------------------------------------
  static const String home = '/home';
  static const String explore = '/explore';
  static const String bookings = '/bookings';
  static const String profile = '/profile';

  static const List<String> shellTabs = [home, explore, bookings, profile];

  // --- Stations -----------------------------------------------------------
  static const String stationMap = '/map';
  static const String stationDetails = '/station/:id';
  static const String stationFilters = '/filters';

  static String station(String id) => '/station/$id';

  // --- Booking flow -------------------------------------------------------
  static const String createBooking = '/book/:stationId';
  static const String bookingDetails = '/booking/:id';
  static const String bookingConfirmation = '/booking-confirmed';

  static String booking(String id) => '/booking/$id';

  // --- Vehicles -----------------------------------------------------------
  static const String vehicles = '/vehicles';
  static const String addVehicle = '/vehicles/add';
  static const String editVehicle = '/vehicle/:id/edit';

  static String vehicleEdit(String id) => '/vehicle/$id/edit';

  // --- Charging history ---------------------------------------------------
  static const String chargingHistory = '/charging-history';
  static const String sessionDetails = '/session/:id';

  static String session(String id) => '/session/$id';

  // --- Station owner management ------------------------------------------
  static const String myStations = '/my-stations';
  static const String addStation = '/my-stations/add';
  static const String editStation = '/my-station/:id/edit';
  static const String stationAvailability = '/my-station/:id/availability';
  static const String stationBookings = '/my-station/:id/bookings';

  static String stationEdit(String id) => '/my-station/$id/edit';
  static String stationAvailabilityFor(String id) =>
      '/my-station/$id/availability';
  static String stationBookingsFor(String id) => '/my-station/$id/bookings';

  // --- Profile, settings, notifications -----------------------------------
  static const String editProfile = '/profile/edit';
  static const String settings = '/settings';
  static const String notifications = '/notifications';

  // --- Misc ---------------------------------------------------------------
  static const String notFound = '/not-found';
}

/// Route names usable as [Navigator] keys / dialogs where needed.
abstract final class RouteNames {
  static const String splash = 'splash';
  static const String onboarding = 'onboarding';
  static const String welcome = 'welcome';
  static const String signIn = 'signIn';
  static const String signUp = 'signUp';
  static const String verifyEmail = 'verifyEmail';
  static const String forgotPassword = 'forgotPassword';
  static const String resetPassword = 'resetPassword';
  static const String home = 'home';
  static const String explore = 'explore';
  static const String bookings = 'bookings';
  static const String profile = 'profile';
}
