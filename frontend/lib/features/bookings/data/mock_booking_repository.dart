import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/booking.dart';
import '../domain/booking_repository.dart';

/// ---------------------------------------------------------------------------
/// DEMO DATA — sample bookings for UI development. Not backed by a server.
/// ---------------------------------------------------------------------------
abstract final class DemoBookings {
  static List<Booking> all() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime at(int dayOffset, int hour, {int minute = 0}) =>
        today.add(Duration(days: dayOffset, hours: hour, minutes: minute));

    return [
      Booking(
        id: 'bk-5001',
        reference: 'EV-4821',
        stationId: 'st-1001',
        stationName: 'VoltCorner Potsdamer Platz',
        stationAddress: 'Alte Potsdamer Straße 7, 10785 Berlin',
        vehicleId: 'veh-1',
        vehicleLabel: 'Tesla Model 3',
        startTime: at(1, 9),
        endTime: at(1, 11),
        status: BookingStatus.confirmed,
        createdAt: now.subtract(const Duration(days: 2)),
        estimatedEnergyKwh: 46,
        estimatedCost: 22.54,
      ),
      Booking(
        id: 'bk-5002',
        reference: 'EV-4877',
        stationId: 'st-1004',
        stationName: 'ElecHub Ostbahnhof',
        stationAddress: 'Friedrichstraße 12, 10117 Berlin',
        vehicleId: 'veh-2',
        vehicleLabel: 'Volkswagen ID.4',
        startTime: at(3, 17),
        endTime: at(3, 18),
        status: BookingStatus.pending,
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      Booking(
        id: 'bk-5003',
        reference: 'EV-4755',
        stationId: 'st-1006',
        stationName: 'AutoStop Schöneberg',
        stationAddress: 'Akazienstraße 30, 10827 Berlin',
        vehicleId: 'veh-1',
        vehicleLabel: 'Tesla Model 3',
        startTime: at(-6, 14),
        endTime: at(-6, 15),
        status: BookingStatus.completed,
        createdAt: now.subtract(const Duration(days: 8)),
        estimatedEnergyKwh: 18.6,
        estimatedCost: 6.51,
      ),
      Booking(
        id: 'bk-5004',
        reference: 'EV-4690',
        stationId: 'st-1003',
        stationName: 'CityPark Mitte Garage',
        stationAddress: 'Invalidenstraße 117, 10115 Berlin',
        vehicleId: 'veh-2',
        vehicleLabel: 'Volkswagen ID.4',
        startTime: at(-12, 10),
        endTime: at(-12, 12),
        status: BookingStatus.cancelled,
        createdAt: now.subtract(const Duration(days: 14)),
        cancelledAt: now.subtract(const Duration(days: 13)),
        cancellationReason: 'Plans changed (demo cancellation)',
      ),
    ];
  }
}

/// Development-only in-memory [BookingRepository].
///
/// Mirrors backend responsibilities locally so the UI never fakes success:
/// overlapping slots are rejected with a [ValidationException].
class MockBookingRepository implements BookingRepository {
  MockBookingRepository({List<Booking>? seed})
    : _bookings = seed ?? DemoBookings.all();

  final List<Booking> _bookings;
  int _sequence = 5100;

  Future<void> _delay() => Future<void>.delayed(AppConstants.mockLatency);

  @override
  Future<List<Booking>> getBookings() async {
    await _delay();
    final sorted = List<Booking>.of(_bookings)
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    return sorted;
  }

  @override
  Future<Booking> getBooking(String id) async {
    await _delay();
    return _bookings.firstWhere(
      (b) => b.id == id,
      orElse: () => throw const ValidationException('Booking not found'),
    );
  }

  @override
  Future<Booking> createBooking(CreateBookingInput input) async {
    await _delay();

    if (!input.endTime.isAfter(input.startTime)) {
      throw const ValidationException('End time must be after the start time');
    }

    final conflict = _bookings.any(
      (b) =>
          b.stationId == input.stationId &&
          !b.status.isCancelledLike &&
          input.startTime.isBefore(b.endTime) &&
          input.endTime.isAfter(b.startTime),
    );
    if (conflict) {
      throw const ValidationException(
        'This slot overlaps with an existing booking at this station. '
        'Please pick another time.',
        code: 'slot_conflict',
      );
    }

    final booking = Booking(
      id: 'bk-${DateTime.now().millisecondsSinceEpoch}',
      reference: 'EV-${_sequence++}',
      stationId: input.stationId,
      stationName: 'Demo station', // enriched by the booking screen provider
      stationAddress: '',
      vehicleId: input.vehicleId,
      vehicleLabel: '',
      startTime: input.startTime,
      endTime: input.endTime,
      status: BookingStatus.pending,
      createdAt: DateTime.now(),
      estimatedEnergyKwh: input.estimatedEnergyKwh,
      estimatedCost: input.estimatedCost,
    );
    _bookings.add(booking);
    return booking;
  }

  @override
  Future<Booking> cancelBooking(String id) async {
    await _delay();
    final index = _bookings.indexWhere((b) => b.id == id);
    if (index == -1) throw const ValidationException('Booking not found');

    final booking = _bookings[index];
    if (!booking.canRequestCancellation) {
      throw const ValidationException(
        'This booking can no longer be cancelled. The server decides '
        'whether a cancellation is allowed.',
        code: 'not_cancellable',
      );
    }

    final updated = booking.copyWith(
      status: BookingStatus.cancelled,
      cancelledAt: DateTime.now(),
      cancellationReason: 'Cancelled by driver (demo)',
    );
    _bookings[index] = updated;
    return updated;
  }

  @override
  Future<List<Booking>> getBookingsForStation(String stationId) async {
    await _delay();
    return _bookings.where((b) => b.stationId == stationId).toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }
}
