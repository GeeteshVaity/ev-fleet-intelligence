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

class PlatformControllerTest {
    private MockMvc mockMvc;
    private VehicleService service;

    @BeforeEach
    void setUp() {
        service = mock(VehicleService.class);
        mockMvc = MockMvcBuilders.standaloneSetup(new VehicleController(service)).build();
    }

    @Test
    void listsAuthenticatedUserVehicles() throws Exception {
        Vehicle vehicle = new Vehicle();
        vehicle.setVehicleType("CAR");
        vehicle.setModel("Model 3");
        when(service.list("user-1")).thenReturn(List.of(vehicle));

        mockMvc.perform(get("/api/vehicles").header("X-User-Sub", "user-1"))
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
                        .header("X-User-Sub", "user-1")
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
                .andExpect(status().isBadRequest());
        verifyNoInteractions(service);
    }

    @Test
    void returnsNoContentWhenVehicleIsDeleted() throws Exception {
        mockMvc.perform(delete("/api/vehicles/7").header("X-User-Sub", "user-1"))
                .andExpect(status().isNoContent());
        verify(service).delete("user-1", 7L);
    }
}
