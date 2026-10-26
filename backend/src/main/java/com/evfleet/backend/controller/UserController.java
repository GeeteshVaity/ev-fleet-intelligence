package com.evfleet.backend.controller;

import com.evfleet.backend.model.AppUser;
import com.evfleet.backend.service.UserService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/users/me")
public class UserController {
    public record OnboardingRequest(String role, Boolean onboardingCompleted, Integer onboardingStep) {}
    private final UserService service;
    public UserController(UserService service) { this.service = service; }
    @PostMapping @ResponseStatus(HttpStatus.CREATED) public AppUser create(@RequestHeader("X-User-Sub") String sub, @Valid @RequestBody AppUser body) { return service.createOrUpdate(sub, body); }
    @GetMapping public AppUser get(@RequestHeader("X-User-Sub") String sub) { return service.current(sub); }
    @PutMapping public AppUser update(@RequestHeader("X-User-Sub") String sub, @Valid @RequestBody AppUser body) { return service.createOrUpdate(sub, body); }
    @PutMapping("/onboarding") public AppUser onboarding(@RequestHeader("X-User-Sub") String sub, @RequestBody OnboardingRequest body) {
        return service.updateOnboarding(sub, body.role(), body.onboardingCompleted(), body.onboardingStep());
    }
}
