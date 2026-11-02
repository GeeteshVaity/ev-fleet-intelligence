import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../domain/booking.dart';
import '../domain/booking_repository.dart';
import 'booking_remote_data_source.dart';
import 'mock_booking_repository.dart';

/// Booking repository backed by the Spring Boot REST API. All authority
/// (availability, conflicts, cancellation rights) stays server-side.
class BookingRepositoryImpl implements BookingRepository {
  BookingRepositoryImpl(this._remote);

  final BookingRemoteDataSource _remote;

  @override
  Future<List<Booking>> getBookings() => _remote.fetchBookings();

  @override
  Future<Booking> getBooking(String id) => _remote.fetchBooking(id);

  @override
  Future<Booking> createBooking(CreateBookingInput input) =>
      _remote.createBooking(input);

  @override
  Future<Booking> cancelBooking(String id) => _remote.cancelBooking(id);

  @override
  Future<List<Booking>> getBookingsForStation(String stationId) =>
      _remote.fetchBookingsForStation(stationId);
}

/// DI: demo repository until `API_BASE_URL` is configured.
final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  if (ApiConstants.isMockBackend) return MockBookingRepository();
  return BookingRepositoryImpl(
    BookingRemoteDataSource(ref.watch(dioClientProvider)),
  );
});
