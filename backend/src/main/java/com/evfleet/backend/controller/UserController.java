
package com.evfleet.backend.controller;

import com.evfleet.backend.model.AppUser;
import com.evfleet.backend.security.CurrentUser;
import com.evfleet.backend.service.UserService;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/users/me")
public class UserController {

    public record ProfileRequest(
            @NotBlank
            @Size(max = 120)
            String fullName,

            @NotBlank
            @Email
            @Size(max = 254)
            String email,

            @Size(max = 30)
            String phone,

            @Size(max = 30)
            String role,

            @Size(max = 150)
            String businessName,

            @Size(max = 30)
            String providerType,

            @Size(max = 500)
            String address
    ) {
        public ProfileRequest(
                String fullName,
                String email,
                String phone,
                String role
        ) {
            this(fullName, email, phone, role, null, null, null);
        }
    }

    public record OnboardingRequest(
            @Size(max = 30)
            String role,

            Boolean onboardingCompleted,

            @Min(0)
            @Max(20)
            Integer onboardingStep
    ) {}

    private final UserService service;

    public UserController(UserService service) {
        this.service = service;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public AppUser create(
            Authentication auth,
            @Valid @RequestBody ProfileRequest body
    ) {
        return service.createOrUpdate(
                CurrentUser.subject(auth),
                body
        );
    }

    @GetMapping
    public AppUser get(Authentication auth) {
        return service.current(CurrentUser.subject(auth));
    }

    @PutMapping
    public AppUser update(
            Authentication auth,
            @Valid @RequestBody ProfileRequest body
    ) {
        return service.createOrUpdate(
                CurrentUser.subject(auth),
                body
        );
    }

    @PutMapping("/onboarding")
    public AppUser onboarding(
            Authentication auth,
            @Valid @RequestBody OnboardingRequest body
    ) {
        return service.updateOnboarding(
                CurrentUser.subject(auth),
                body.role(),
                body.onboardingCompleted(),
                body.onboardingStep()
        );
    }
}
