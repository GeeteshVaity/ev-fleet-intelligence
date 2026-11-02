package com.evfleet.backend.controller;

import com.evfleet.backend.model.AppUser;
import com.evfleet.backend.service.UserService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import jakarta.validation.Valid;
import org.springframework.security.core.Authentication;
import static com.evfleet.backend.security.CurrentUser.subject;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

@RestController
@RequestMapping("/api/users/me")
public class UserController {
    public record ProfileRequest(
            @NotBlank @Size(max = 120) String fullName,
            @NotBlank @Email @Size(max = 254) String email,
            @Size(max = 30) String phone,
            @Size(max = 30) String role) {}

    public record OnboardingRequest(
            @Size(max = 30) String role,
            Boolean onboardingCompleted,
            Integer onboardingStep) {}
    private final UserService service;
    public UserController(UserService service) { this.service = service; }
    @PostMapping @ResponseStatus(HttpStatus.CREATED)
    public AppUser create(Authentication auth, @Valid @RequestBody ProfileRequest body) {
        return service.createOrUpdate(subject(auth), body);
    }
    @GetMapping public AppUser get(Authentication auth) { return service.current(subject(auth)); }
    @PutMapping
    public AppUser update(Authentication auth, @Valid @RequestBody ProfileRequest body) {
        return service.createOrUpdate(subject(auth), body);
    }
    @PutMapping("/onboarding") public AppUser onboarding(Authentication auth, @RequestBody OnboardingRequest body) {
        return service.updateOnboarding(subject(auth), body.role(), body.onboardingCompleted(), body.onboardingStep());
    }
}
