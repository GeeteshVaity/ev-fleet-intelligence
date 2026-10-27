package com.evfleet.backend.controller;

import com.evfleet.backend.model.Vehicle;
import com.evfleet.backend.service.VehicleService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.util.List;

import static org.hamcrest.Matchers.hasSize;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;

class PlatformControllerTest {
    private MockMvc mockMvc;
    private VehicleService service;

    private JwtAuthenticationToken auth() {
        return new JwtAuthenticationToken(
                Jwt.withTokenValue("test-token").header("alg", "none")
                        .claim("sub", "user-1").build());
    }

    @BeforeEach
    void setUp() {
        service = mock(VehicleService.class);
        mockMvc = MockMvcBuilders.standaloneSetup(new VehicleController(service))
                .setControllerAdvice(new com.evfleet.backend.controller.ApiExceptionHandler())
                .build();
    }

    @Test
    void listsAuthenticatedUserVehicles() throws Exception {
        Vehicle vehicle = new Vehicle();
        vehicle.setVehicleType("CAR");
        vehicle.setModel("Model 3");
        when(service.list("user-1")).thenReturn(List.of(vehicle));

        mockMvc.perform(get("/api/vehicles").principal(auth()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(1)))
                .andExpect(jsonPath("$[0].vehicleType").value("CAR"))
                .andExpect(jsonPath("$[0].model").value("Model 3"));
    }

    @Test
    void createsVehicleAndReturnsCreated() throws Exception {
        Vehicle vehicle = new Vehicle();
        vehicle.setVehicleType("CAR");
        vehicle.setModel("Model 3");
        when(service.create(eq("user-1"), any(Vehicle.class))).thenReturn(vehicle);

        mockMvc.perform(post("/api/vehicles")
                        .principal(auth())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"vehicleType":"CAR","model":"Model 3"}
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.vehicleType").value("CAR"));
        verify(service).create(eq("user-1"), any(Vehicle.class));
    }

    @Test
    void requiresIdentityHeaderForUserSpecificRoute() throws Exception {
        mockMvc.perform(get("/api/vehicles"))
                .andExpect(status().isUnauthorized());
        verifyNoInteractions(service);
    }

    @Test
    void returnsNoContentWhenVehicleIsDeleted() throws Exception {
        mockMvc.perform(delete("/api/vehicles/7").principal(auth()))
                .andExpect(status().isNoContent());
        verify(service).delete("user-1", 7L);
    }

    @Test
    void rejectsVehicleWithMissingRequiredFields() throws Exception {
        mockMvc.perform(post("/api/vehicles")
                        .header("X-User-Sub", "user-1")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("Bad Request"))
                .andExpect(jsonPath("$.message").value("Validation failed"))
                .andExpect(jsonPath("$.details.vehicleType").exists())
                .andExpect(jsonPath("$.details.model").exists());
        verifyNoInteractions(service);
    }
}
