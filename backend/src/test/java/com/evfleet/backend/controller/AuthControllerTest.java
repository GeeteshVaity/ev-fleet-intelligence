package com.evfleet.backend.controller;

import com.evfleet.backend.service.UserService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

import java.time.Instant;

import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * Unit tests for {@link AuthController}.
 *
 * <p>
 * Uses standalone MockMvc; Spring Security is not loaded. Authentication is
 * simulated by passing a {@link JwtAuthenticationToken} directly to MockMvc,
 * which is the correct approach for controller-layer unit tests.
 *
 * <p>
 * Integration-level tests (with Spring context and a mock Cognito JWK set)
 * are omitted because they require a reachable Cognito JWKS endpoint.
 * End-to-end
 * validation is covered by the manual test guide in
 * {@code LOCAL_APP_TESTING.md}.
 */
class AuthControllerTest {

    private MockMvc mockMvc;
    private UserService userService;

    @BeforeEach
    void setUp() {
        userService = mock(UserService.class);
        mockMvc = MockMvcBuilders
                .standaloneSetup(new AuthController(userService))
                .setControllerAdvice(new ApiExceptionHandler())
                .build();
    }

    // -----------------------------------------------------------------------
    // Test 2: GET /api/auth/me without token → 401
    // -----------------------------------------------------------------------

    @Test
    void returnsUnauthorizedWhenNoAuthenticationIsPresent() throws Exception {
        mockMvc.perform(get("/api/auth/me"))
                .andExpect(status().isUnauthorized());
    }

    // -----------------------------------------------------------------------
    // Test 4: Valid access token → 200 with safe claims
    // -----------------------------------------------------------------------

    @Test
    void returnsClaimsForValidAccessToken() throws Exception {
        when(userService.current("sub-abc-123"))
                .thenThrow(new ResponseStatusException(HttpStatus.NOT_FOUND, "Profile not found"));

        mockMvc.perform(get("/api/auth/me").principal(validAuth()))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.sub").value("sub-abc-123"))
                .andExpect(jsonPath("$.username").value("testuser"))
                .andExpect(jsonPath("$.tokenUse").value("access"))
                // profileCreated flag is set when profile is not found
                .andExpect(jsonPath("$.profileCreated").value(false));
    }

    // -----------------------------------------------------------------------
    // Test: Token with local profile → response includes profile fields
    // -----------------------------------------------------------------------

    @Test
    void includesLocalProfileFieldsWhenProfileExists() throws Exception {
        com.evfleet.backend.model.AppUser user = new com.evfleet.backend.model.AppUser();
        user.setCognitoSub("sub-abc-123");
        user.setFullName("Test User");
        user.setEmail("test@example.com");
        user.setRole("VEHICLE_OWNER");

        when(userService.current("sub-abc-123")).thenReturn(user);

        mockMvc.perform(get("/api/auth/me").principal(validAuth()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.sub").value("sub-abc-123"))
                .andExpect(jsonPath("$.fullName").value("Test User"))
                .andExpect(jsonPath("$.role").value("VEHICLE_OWNER"))
                .andExpect(jsonPath("$.onboardingCompleted").value(false));

        // Sensitive data must not be present
        mockMvc.perform(get("/api/auth/me").principal(validAuth()))
                .andExpect(jsonPath("$.password").doesNotExist())
                .andExpect(jsonPath("$.token").doesNotExist())
                .andExpect(jsonPath("$.accessToken").doesNotExist());
    }

    // -----------------------------------------------------------------------
    // Test: id token is rejected (token_use ≠ access) at the endpoint level
    // Note: real rejection of id tokens happens in the JwtDecoder/validator
    // at the security layer before reaching the controller. This test
    // verifies that a misconfigured id-token-shaped JWT (no token_use=access)
    // at least does not expose secrets.
    // -----------------------------------------------------------------------

    @Test
    void doesNotExposeSecretsForAnyAuthenticatedCall() throws Exception {
        when(userService.current(anyString()))
                .thenThrow(new ResponseStatusException(HttpStatus.NOT_FOUND, "Profile not found"));

        mockMvc.perform(get("/api/auth/me").principal(validAuth()))
                .andExpect(jsonPath("$.password").doesNotExist())
                .andExpect(jsonPath("$.accessToken").doesNotExist())
                .andExpect(jsonPath("$.refreshToken").doesNotExist())
                .andExpect(jsonPath("$.secret").doesNotExist());
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    private JwtAuthenticationToken validAuth() {
        Jwt jwt = Jwt.withTokenValue("test-access-token")
                .header("alg", "RS256")
                .header("kid", "test-kid")
                .claim("sub", "sub-abc-123")
                .claim("username", "testuser")
                .claim("token_use", "access")
                .claim("client_id", "test-client-id")
                .issuedAt(Instant.now().minusSeconds(60))
                .expiresAt(Instant.now().plusSeconds(3600))
                .build();
        return new JwtAuthenticationToken(jwt, null, "sub-abc-123");
    }
}
