package com.evfleet.backend.controller;

import com.evfleet.backend.model.ChargingSession;
import com.evfleet.backend.service.SessionService;
import com.evfleet.backend.service.UserService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/api")
public class SessionController {
    private final SessionService service;
    private final UserService users;
    public SessionController(SessionService service, UserService users) { this.service = service; this.users = users; }
    @PostMapping("/bookings/{bookingId}/sessions") @ResponseStatus(HttpStatus.CREATED) public ChargingSession start(@RequestHeader("X-User-Sub") String sub, @PathVariable Long bookingId) { return service.start(sub, bookingId); }
    @GetMapping("/sessions/{id}") public ChargingSession get(@RequestHeader("X-User-Sub") String sub, @PathVariable Long id) { return service.get(sub, id); }
    @PutMapping("/sessions/{id}/complete") public ChargingSession complete(@RequestHeader("X-User-Sub") String sub, @PathVariable Long id, @RequestBody ChargingSession body) { return service.complete(sub, id, body); }
    @GetMapping("/users/me/sessions") public List<ChargingSession> list(@RequestHeader("X-User-Sub") String sub) { return users.sessions(sub); }
}
