
package com.evfleet.backend.controller;

import com.evfleet.backend.model.Booking;
import com.evfleet.backend.service.BookingService;
import com.evfleet.backend.security.CurrentUser;

import jakarta.validation.Valid;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/bookings")
public class BookingController {

    private final BookingService service;

    public BookingController(BookingService service) {
        this.service = service;
    }

    // Create a new booking.
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Booking create(
            Authentication auth,
            @Valid @RequestBody Booking body
    ) {
        return service.create(CurrentUser.subject(auth), body);
    }

    // List bookings belonging to the authenticated user.
    @GetMapping
    public List<Booking> list(Authentication auth) {
        return service.list(CurrentUser.subject(auth));
    }

    // Retrieve a booking accessible to the authenticated user.
    @GetMapping("/{id}")
    public Booking get(
            Authentication auth,
            @PathVariable("id") Long id
    ) {
        return service.get(CurrentUser.subject(auth), id);
    }

    // Cancel a booking as its vehicle owner.
    @PutMapping("/{id}/cancel")
    public Booking cancel(
            Authentication auth,
            @PathVariable("id") Long id
    ) {
        return service.cancel(CurrentUser.subject(auth), id);
    }

    // Confirm a booking as its station owner.
    @PutMapping("/{id}/confirm")
    public Booking confirm(
            Authentication auth,
            @PathVariable("id") Long id
    ) {
        return service.confirm(CurrentUser.subject(auth), id);
    }

    // Reject a booking as its station owner.
    @PutMapping("/{id}/reject")
    public Booking reject(
            Authentication auth,
            @PathVariable("id") Long id
    ) {
        return service.reject(CurrentUser.subject(auth), id);
    }
}
