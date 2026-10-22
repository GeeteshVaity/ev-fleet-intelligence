package com.evfleet.backend.controller;

import com.evfleet.backend.model.Booking;
import com.evfleet.backend.service.BookingService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import jakarta.validation.Valid;
import java.util.List;

@RestController
@RequestMapping("/api/bookings")
public class BookingController {
    private final BookingService service;
    public BookingController(BookingService service) { this.service = service; }
    @PostMapping @ResponseStatus(HttpStatus.CREATED) public Booking create(@RequestHeader("X-User-Sub") String sub, @Valid @RequestBody Booking body) { return service.create(sub, body); }
    @GetMapping public List<Booking> list(@RequestHeader("X-User-Sub") String sub) { return service.list(sub); }
    @GetMapping("/{id}") public Booking get(@RequestHeader("X-User-Sub") String sub, @PathVariable Long id) { return service.get(sub, id); }
    @PutMapping("/{id}/cancel") public Booking cancel(@RequestHeader("X-User-Sub") String sub, @PathVariable Long id) { return service.cancel(sub, id); }
    @PutMapping("/{id}/confirm") public Booking confirm(@RequestHeader("X-User-Sub") String sub, @PathVariable Long id) { return service.confirm(sub, id); }
    @PutMapping("/{id}/reject") public Booking reject(@RequestHeader("X-User-Sub") String sub, @PathVariable Long id) { return service.reject(sub, id); }
}
