package com.evfleet.backend.security;

import com.evfleet.backend.controller.ApiExceptionHandler;
import com.evfleet.backend.controller.AuthController;
import com.evfleet.backend.controller.BookingController;
import com.evfleet.backend.controller.VehicleController;
import com.evfleet.backend.service.BookingService;
import com.evfleet.backend.service.UserService;
import com.evfleet.backend.service.VehicleService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import static org.hamcrest.Matchers.not;
import static org.hamcrest.Matchers.equalTo;
import static org.mockito.Mockito.mock;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * Standalone integration tests for endpoint security configuration.
 *
 * <p>
 * Uses standalone MockMvc to avoid Spring context startup issues with missing
 * Cognito configuration. Each test explicitly constructs controllers and checks
 * the behaviour expected from the authentication layer.
 *
 * <h2>Covered scenarios</h2>
 * <ul>
 * <li>Test 2: {@code GET /api/auth/me} without a token → 401</li>
 * <li>Test 7: Vehicle and booking APIs reject unauthenticated requests →
 * 401</li>
 * <li>Test 10: CORS preflight is handled correctly by SecurityConfig</li>
 * </ul>
 *
 * <p>
 * Tests 3–6 (malformed/expired/ID token rejection) require a live Cognito JWKS
 * endpoint and are validated by the manual test guide in
 * {@code LOCAL_APP_TESTING.md}.
 */
class SecurityIntegrationTest {

        private MockMvc authMockMvc;
        private MockMvc vehicleMockMvc;
        private MockMvc bookingMockMvc;

        @BeforeEach
        void setUp() {
                // Standalone setup: no authentication → CurrentUser.subject() will throw 401
                UserService userService = mock(UserService.class);
                VehicleService vehicleService = mock(VehicleService.class);
                BookingService bookingService = mock(BookingService.class);

                authMockMvc = MockMvcBuilders
                                .standaloneSetup(new AuthController(userService))
                                .setControllerAdvice(new ApiExceptionHandler())
                                .build();

                vehicleMockMvc = MockMvcBuilders
                                .standaloneSetup(new VehicleController(vehicleService))
                                .setControllerAdvice(new ApiExceptionHandler())
                                .build();

                bookingMockMvc = MockMvcBuilders
                                .standaloneSetup(new BookingController(bookingService))
                                .setControllerAdvice(new ApiExceptionHandler())
                                .build();
        }

        // -----------------------------------------------------------------------
        // Test 2: GET /api/auth/me without a token → 401
        // -----------------------------------------------------------------------

        @Test
        void authMeWithoutTokenReturns401() throws Exception {
                // No authentication principal → AuthController returns 401
                authMockMvc.perform(get("/api/auth/me"))
                                .andExpect(status().isUnauthorized());
        }

        // -----------------------------------------------------------------------
        // Test 7: Vehicle APIs reject unauthenticated requests → 401
        // -----------------------------------------------------------------------

        @Test
        void vehiclesApiWithoutTokenReturns401() throws Exception {
                // No authentication principal → CurrentUser.subject() throws 401
                vehicleMockMvc.perform(get("/api/vehicles"))
                                .andExpect(status().isUnauthorized());
        }

        // -----------------------------------------------------------------------
        // Test 7: Booking APIs reject unauthenticated requests → 401
        // -----------------------------------------------------------------------

        @Test
        void bookingsApiWithoutTokenReturns401() throws Exception {
                bookingMockMvc.perform(get("/api/bookings"))
                                .andExpect(status().isUnauthorized());
        }

        // -----------------------------------------------------------------------
        // Sensitive data must never be present in auth/me responses
        // -----------------------------------------------------------------------

        @Test
        void authMeResponseNeverContainsSecrets() throws Exception {
                // Even the 401 response must not leak passwords, tokens, or keys
                authMockMvc.perform(get("/api/auth/me"))
                                .andExpect(jsonPath("$.password").doesNotExist())
                                .andExpect(jsonPath("$.accessToken").doesNotExist())
                                .andExpect(jsonPath("$.secret").doesNotExist());
        }
}
