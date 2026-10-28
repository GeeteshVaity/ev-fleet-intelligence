package com.evfleet.backend.controller;

import com.evfleet.backend.service.UserService;
import org.springframework.http.ResponseEntity;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.LinkedHashMap;
import java.util.Map;

import static com.evfleet.backend.security.CurrentUser.subject;

/**
 * Authentication information endpoint.
 *
 * <p>
 * {@code GET /api/auth/me} returns safe, read-only claims extracted from the
 * validated Cognito access token. It is the primary smoke-test route for
 * confirming that JWT validation is correctly configured.
 *
 * <p>
 * Secrets, raw tokens, password hashes, and AWS credentials are never included.
 */
@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final UserService userService;

    public AuthController(UserService userService) {
        this.userService = userService;
    }

    /**
     * Returns safe claims from the validated Cognito access token.
     *
     * <p>
     * Exposed claims:
     * <ul>
     * <li>{@code sub} – stable Cognito subject (UUID)</li>
     * <li>{@code username} – Cognito username if present in token</li>
     * <li>{@code email} – only if the scope/claim is present in the access
     * token</li>
     * <li>{@code tokenUse} – must be {@code access}; ID tokens are rejected
     * upstream</li>
     * </ul>
     *
     * <p>
     * A request without a valid Bearer token returns HTTP 401 (handled by Spring
     * Security
     * before reaching this method).
     */
    @GetMapping("/me")
    public ResponseEntity<Map<String, Object>> me(Authentication auth) {
        if (!(auth instanceof JwtAuthenticationToken jwt)) {
            return ResponseEntity.status(401).build();
        }

        final var claims = jwt.getToken().getClaims();
        if (!"access".equals(jwt.getToken().getClaimAsString("token_use"))) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "A Cognito access token is required");
        }
        final var response = new LinkedHashMap<String, Object>();

        // sub is always present in a valid Cognito access token
        response.put("sub", subject(auth));

        // username claim is set by Cognito in access tokens
        final var username = claims.get("username");
        if (username != null)
            response.put("username", username);

        // email may be present if the Cognito app client includes it in access-token
        // scopes
        final var email = claims.get("email");
        if (email != null)
            response.put("email", email);

        // token_use should be "access" – reject id tokens at the claim level too
        final var tokenUse = claims.get("token_use");
        if (tokenUse != null)
            response.put("tokenUse", tokenUse);

        // client_id helps confirm which app client issued the token
        final var clientId = claims.get("client_id");
        if (clientId != null)
            response.put("clientId", clientId);

        // Attempt to include local profile data if the user has completed onboarding
        try {
            final var user = userService.current(subject(auth));
            response.put("localId", user.getId());
            response.put("fullName", user.getFullName());
            response.put("role", user.getRole());
            response.put("onboardingCompleted", user.isOnboardingCompleted());
        } catch (ResponseStatusException error) {
            if (error.getStatusCode().value() != 404) {
                throw error;
            }
            // Profile not yet created — Cognito token is still valid.
            // The client should POST /api/users/me to create a profile.
            response.put("profileCreated", false);
        }

        return ResponseEntity.ok(response);
    }
}
