package com.evfleet.backend.controller;

import com.evfleet.backend.model.ChargingSession;
import com.evfleet.backend.service.SessionService;
import com.evfleet.backend.service.UserService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import java.util.List;
import org.springframework.security.core.Authentication;
import static com.evfleet.backend.security.CurrentUser.subject;

@RestController
@RequestMapping("/api")
public class SessionController {
    private final SessionService service;
    private final UserService users;
    public SessionController(SessionService service, UserService users) { this.service = service; this.users = users; }
    @PostMapping("/bookings/{bookingId}/sessions") @ResponseStatus(HttpStatus.CREATED) public ChargingSession start(Authentication auth, @PathVariable Long bookingId) { return service.start(subject(auth), bookingId); }
    @GetMapping("/sessions/{id}") public ChargingSession get(Authentication auth, @PathVariable Long id) { return service.get(subject(auth), id); }
    @PutMapping("/sessions/{id}/complete") public ChargingSession complete(Authentication auth, @PathVariable Long id, @RequestBody ChargingSession body) { return service.complete(subject(auth), id, body); }
    @GetMapping("/users/me/sessions") public List<ChargingSession> list(Authentication auth) { return users.sessions(subject(auth)); }
}
