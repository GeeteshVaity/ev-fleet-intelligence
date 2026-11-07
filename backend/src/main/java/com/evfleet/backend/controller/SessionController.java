
package com.evfleet.backend.controller;

import com.evfleet.backend.model.ChargingSession;
import com.evfleet.backend.service.SessionService;
import com.evfleet.backend.service.UserService;
import com.evfleet.backend.security.CurrentUser;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api")
public class SessionController {

    private final SessionService service;
    private final UserService users;

    public SessionController(
            SessionService service,
            UserService users
    ) {
        this.service = service;
        this.users = users;
    }

    // Start a charging session for a confirmed booking.
    @PostMapping("/bookings/{bookingId}/sessions")
    @ResponseStatus(HttpStatus.CREATED)
    public ChargingSession start(
            Authentication auth,
            @PathVariable("bookingId") Long bookingId
    ) {
        return service.start(
                CurrentUser.subject(auth),
                bookingId
        );
    }

    // Retrieve a charging session by its ID.
    @GetMapping("/sessions/{id}")
    public ChargingSession get(
            Authentication auth,
            @PathVariable("id") Long id
    ) {
        return service.get(
                CurrentUser.subject(auth),
                id
        );
    }

    // Complete a charging session and calculate its final bill.
    @PutMapping("/sessions/{id}/complete")
    public ChargingSession complete(
            Authentication auth,
            @PathVariable("id") Long id,
            @RequestBody ChargingSession body
    ) {
        return service.complete(
                CurrentUser.subject(auth),
                id,
                body
        );
    }

    // List charging sessions belonging to the authenticated vehicle owner.
    @GetMapping("/users/me/sessions")
    public List<ChargingSession> list(Authentication auth) {
        return users.sessions(CurrentUser.subject(auth));
    }

    // Recover a session using its booking ID.
    @GetMapping("/bookings/{bookingId}/session")
    public ChargingSession getByBooking(
            Authentication auth,
            @PathVariable("bookingId") Long bookingId
    ) {
        return service.getByBooking(
                CurrentUser.subject(auth),
                bookingId
        );
    }
}
