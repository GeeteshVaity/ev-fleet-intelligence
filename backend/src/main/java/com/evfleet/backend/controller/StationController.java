
package com.evfleet.backend.controller;

import com.evfleet.backend.model.Booking;
import com.evfleet.backend.model.ChargerAvailability;
import com.evfleet.backend.model.ChargingStation;
import com.evfleet.backend.security.CurrentUser;
import com.evfleet.backend.service.BookingService;
import com.evfleet.backend.service.StationService;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/stations")
public class StationController {

    private final StationService service;
    private final BookingService bookings;

    public StationController(
            StationService service,
            BookingService bookings
    ) {
        this.service = service;
        this.bookings = bookings;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ChargingStation create(
            Authentication auth,
            @Valid @RequestBody ChargingStation body
    ) {
        return service.create(CurrentUser.subject(auth), body);
    }

    @GetMapping
    public List<ChargingStation> list() {
        return service.list();
    }

    @GetMapping("/nearby")
    public List<ChargingStation> nearby(
            @RequestParam double latitude,
            @RequestParam double longitude,
            @RequestParam double radiusKm
    ) {
        return service.nearby(latitude, longitude, radiusKm);
    }

    @GetMapping("/mine")
    public List<ChargingStation> mine(Authentication auth) {
        return service.mine(CurrentUser.subject(auth));
    }

    @GetMapping("/{id}")
    public ChargingStation get(@PathVariable Long id) {
        return service.get(id);
    }

    @PutMapping("/{id}")
    public ChargingStation update(
            Authentication auth,
            @PathVariable Long id,
            @Valid @RequestBody ChargingStation body
    ) {
        return service.update(CurrentUser.subject(auth), id, body);
    }

    @PutMapping("/{id}/status")
    public ChargingStation setStatus(
            Authentication auth,
            @PathVariable Long id,
            @Valid @RequestBody StatusRequest body
    ) {
        return service.setActive(
                CurrentUser.subject(auth),
                id,
                body.active()
        );
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(Authentication auth, @PathVariable Long id) {
        service.deactivate(CurrentUser.subject(auth), id);
    }

    @GetMapping("/{id}/availability")
    public List<ChargerAvailability> availability(
            @PathVariable Long id
    ) {
        return service.availability(id);
    }

    @PostMapping("/{id}/availability")
    @ResponseStatus(HttpStatus.CREATED)
    public ChargerAvailability addAvailability(
            Authentication auth,
            @PathVariable Long id,
            @Valid @RequestBody ChargerAvailability body
    ) {
        return service.addAvailability(
                CurrentUser.subject(auth),
                id,
                body
        );
    }

    @PutMapping("/{id}/availability/{windowId}")
    public ChargerAvailability updateAvailability(
            Authentication auth,
            @PathVariable Long id,
            @PathVariable Long windowId,
            @Valid @RequestBody ChargerAvailability body
    ) {
        return service.updateAvailability(
                CurrentUser.subject(auth),
                id,
                windowId,
                body
        );
    }

    @DeleteMapping("/{id}/availability/{windowId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteAvailability(
            Authentication auth,
            @PathVariable Long id,
            @PathVariable Long windowId
    ) {
        service.deleteAvailability(
                CurrentUser.subject(auth),
                id,
                windowId
        );
    }

    @GetMapping("/{id}/bookings")
    public List<Booking> bookings(
            Authentication auth,
            @PathVariable Long id
    ) {
        return bookings.stationBookings(
                CurrentUser.subject(auth),
                id
        );
    }

    public record StatusRequest(
            @NotNull Boolean active
    ) {}
}
