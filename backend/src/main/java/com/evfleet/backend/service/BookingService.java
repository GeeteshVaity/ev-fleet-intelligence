package com.evfleet.backend.service;

import com.evfleet.backend.model.Booking;
import org.springframework.stereotype.Service;
import java.util.List;

@Service
public class BookingService {
    private final PlatformService platform;
    public BookingService(PlatformService platform) { this.platform = platform; }
    public Booking create(String sub, Booking booking) { return platform.createBooking(sub, booking); }
    public List<Booking> list(String sub) { return platform.bookings(sub); }
    public Booking get(String sub, Long id) { return platform.booking(sub, id); }
    public Booking cancel(String sub, Long id) { return platform.transition(sub, id, "CANCELLED"); }
    public Booking confirm(String sub, Long id) { return platform.transition(sub, id, "CONFIRMED"); }
    public Booking reject(String sub, Long id) { return platform.transition(sub, id, "REJECTED"); }
    public List<Booking> stationBookings(String sub, Long stationId) { return platform.stationBookings(sub, stationId); }
}
