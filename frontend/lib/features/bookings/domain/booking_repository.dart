import 'booking.dart';

/// Contract for booking data access (mock today, Spring Boot later).
abstract interface class BookingRepository {
  /// Every booking of the signed-in user, newest first.
  Future<List<Booking>> getBookings();

  Future<Booking> getBooking(String id);

  /// Creates a booking. Throws [ValidationException] when the requested slot
  /// conflicts with an existing booking — never fakes success.
  Future<Booking> createBooking(CreateBookingInput input);

  /// Requests cancellation. The backend re-checks authorization; the mock
  /// repository mirrors the same rule against local demo data.
  Future<Booking> cancelBooking(String id);

  /// Bookings attached to one station (station-owner view).
  Future<List<Booking>> getBookingsForStation(String stationId);
}
