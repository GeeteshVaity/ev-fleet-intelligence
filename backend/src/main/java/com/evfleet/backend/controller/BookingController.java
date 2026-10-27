package com.evfleet.backend.controller;

import com.evfleet.backend.model.Booking;
import com.evfleet.backend.service.BookingService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.security.core.Authentication;
import static com.evfleet.backend.security.CurrentUser.subject;

@RestController
@RequestMapping("/api/bookings")
public class BookingController {
    private final BookingService service;
    public BookingController(BookingService service) { this.service = service; }
    @PostMapping @ResponseStatus(HttpStatus.CREATED) public Booking create(Authentication auth, @Valid @RequestBody Booking body) { return service.create(subject(auth), body); }
    @GetMapping public List<Booking> list(Authentication auth) { return service.list(subject(auth)); }
    @GetMapping("/{id}") public Booking get(Authentication auth, @PathVariable Long id) { return service.get(subject(auth), id); }
    @PutMapping("/{id}/cancel") public Booking cancel(Authentication auth, @PathVariable Long id) { return service.cancel(subject(auth), id); }
    @PutMapping("/{id}/confirm") public Booking confirm(Authentication auth, @PathVariable Long id) { return service.confirm(subject(auth), id); }
    @PutMapping("/{id}/reject") public Booking reject(Authentication auth, @PathVariable Long id) { return service.reject(subject(auth), id); }
}
