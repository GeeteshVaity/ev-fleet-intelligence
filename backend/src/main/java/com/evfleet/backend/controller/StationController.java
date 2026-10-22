package com.evfleet.backend.controller;

import com.evfleet.backend.model.*;
import com.evfleet.backend.service.StationService;
import com.evfleet.backend.service.BookingService;
import com.evfleet.backend.model.Booking;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/api/stations")
public class StationController {
    private final StationService service;
    private final BookingService bookings;
    public StationController(StationService service, BookingService bookings) { this.service = service; this.bookings = bookings; }
    @PostMapping @ResponseStatus(HttpStatus.CREATED) public ChargingStation create(@RequestHeader("X-User-Sub") String sub, @RequestBody ChargingStation body) { return service.create(sub, body); }
    @GetMapping public List<ChargingStation> list() { return service.list(); }
    @GetMapping("/nearby") public List<ChargingStation> nearby(@RequestParam double latitude, @RequestParam double longitude, @RequestParam double radiusKm) { return service.nearby(latitude, longitude, radiusKm); }
    @GetMapping("/mine") public List<ChargingStation> mine(@RequestHeader("X-User-Sub") String sub) { return service.mine(sub); }
    @GetMapping("/{id}") public ChargingStation get(@PathVariable Long id) { return service.get(id); }
    @PutMapping("/{id}") public ChargingStation update(@RequestHeader("X-User-Sub") String sub, @PathVariable Long id, @RequestBody ChargingStation body) { return service.update(sub, id, body); }
    @DeleteMapping("/{id}") @ResponseStatus(HttpStatus.NO_CONTENT) public void delete(@RequestHeader("X-User-Sub") String sub, @PathVariable Long id) { service.deactivate(sub, id); }
    @GetMapping("/{id}/availability") public List<ChargerAvailability> availability(@PathVariable Long id) { return service.availability(id); }
    @PostMapping("/{id}/availability") @ResponseStatus(HttpStatus.CREATED) public ChargerAvailability addAvailability(@RequestHeader("X-User-Sub") String sub, @PathVariable Long id, @RequestBody ChargerAvailability body) { return service.addAvailability(sub, id, body); }
    @PutMapping("/{id}/availability/{windowId}") public ChargerAvailability updateAvailability(@RequestHeader("X-User-Sub") String sub, @PathVariable Long id, @PathVariable Long windowId, @RequestBody ChargerAvailability body) { return service.updateAvailability(sub, id, windowId, body); }
    @DeleteMapping("/{id}/availability/{windowId}") @ResponseStatus(HttpStatus.NO_CONTENT) public void deleteAvailability(@RequestHeader("X-User-Sub") String sub, @PathVariable Long id, @PathVariable Long windowId) { service.deleteAvailability(sub, id, windowId); }
    @GetMapping("/{id}/bookings") public List<Booking> bookings(@RequestHeader("X-User-Sub") String sub, @PathVariable Long id) { return bookings.stationBookings(sub, id); }
}
