
package com.evfleet.backend.service;

import com.evfleet.backend.model.Booking;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class BookingService {

    private final PlatformService platform;

    public BookingService(PlatformService platform) {
        this.platform = platform;
    }

    // Create a booking as a vehicle owner.
    public Booking create(String sub, Booking booking) {
        return platform.createBooking(sub, booking);
    }

    // List bookings belonging to the authenticated vehicle owner.
    public List<Booking> list(String sub) {
        return platform.bookings(sub);
    }

    // Retrieve a booking accessible to the authenticated user.
    public Booking get(String sub, Long id) {
        return platform.booking(sub, id);
    }

    // Cancel a booking as its vehicle owner.
    public Booking cancel(String sub, Long id) {
        return platform.cancelBooking(sub, id);
    }

    // Confirm a pending booking as the station owner.
    public Booking confirm(String sub, Long id) {
        return platform.decideBooking(sub, id, "CONFIRMED");
    }

    // Reject a pending booking as the station owner.
    public Booking reject(String sub, Long id) {
        return platform.decideBooking(sub, id, "REJECTED");
    }

    // List bookings associated with a provider's station.
    public List<Booking> stationBookings(String sub, Long stationId) {
        return platform.stationBookings(sub, stationId);
    }
}
