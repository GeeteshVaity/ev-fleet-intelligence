package com.evfleet.backend.controller;

import com.evfleet.backend.model.AppUser;
import com.evfleet.backend.service.UserService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import jakarta.validation.Valid;
import org.springframework.security.core.Authentication;
import static com.evfleet.backend.security.CurrentUser.subject;

@RestController
@RequestMapping("/api/users/me")
public class UserController {
    public record OnboardingRequest(String role, Boolean onboardingCompleted, Integer onboardingStep) {}
    private final UserService service;
    public UserController(UserService service) { this.service = service; }
    @PostMapping @ResponseStatus(HttpStatus.CREATED) public AppUser create(Authentication auth, @Valid @RequestBody AppUser body) { return service.createOrUpdate(subject(auth), body); }
    @GetMapping public AppUser get(Authentication auth) { return service.current(subject(auth)); }
    @PutMapping public AppUser update(Authentication auth, @Valid @RequestBody AppUser body) { return service.createOrUpdate(subject(auth), body); }
    @PutMapping("/onboarding") public AppUser onboarding(Authentication auth, @RequestBody OnboardingRequest body) {
        return service.updateOnboarding(subject(auth), body.role(), body.onboardingCompleted(), body.onboardingStep());
    }
}
