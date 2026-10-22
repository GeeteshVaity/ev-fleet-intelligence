package com.evfleet.backend.service;

import com.evfleet.backend.model.AppUser;
import com.evfleet.backend.model.ChargingStation;
import com.evfleet.backend.model.Vehicle;
import com.evfleet.backend.repository.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PlatformServiceTest {
    @Mock private AppUserRepository users;
    @Mock private VehicleRepository vehicles;
    @Mock private ChargingStationRepository stations;
    @Mock private BookingRepository bookings;
    @Mock private ChargingSessionRepository sessions;
    @Mock private ChargerAvailabilityRepository availability;
    @Mock private StationImageRepository images;

    private PlatformService service;
    private AppUser user;

    @BeforeEach
    void setUp() {
        service = new PlatformService(users, vehicles, stations, bookings, sessions, availability, images);
        user = new AppUser();
        user.setCognitoSub("user-1");
        user.setFullName("Test User");
        user.setEmail("test@example.com");
        lenient().when(users.findByCognitoSub("user-1")).thenReturn(Optional.of(user));
    }

    @Test
    void createsVehicleForAuthenticatedOwner() {
        Vehicle input = new Vehicle();
        input.setVehicleType("CAR");
        input.setModel("Model 3");
        when(vehicles.save(input)).thenReturn(input);

        Vehicle result = service.saveVehicle("user-1", input);

        assertThat(result).isSameAs(input);
        assertThat(input.getOwnerUserId()).isEqualTo(user.getId());
        verify(vehicles).save(input);
    }

    @Test
    void rejectsVehicleWithoutRequiredModel() {
        Vehicle input = new Vehicle();
        input.setVehicleType("CAR");

        assertThatThrownBy(() -> service.saveVehicle("user-1", input))
                .isInstanceOf(ResponseStatusException.class)
                .hasMessageContaining("model is required");
        verify(vehicles, never()).save(any());
    }

    @Test
    void rejectsVehicleAccessForAnotherOwner() {
        Vehicle vehicle = new Vehicle();
        vehicle.setOwnerUserId(99L);
        when(vehicles.findById(7L)).thenReturn(Optional.of(vehicle));

        assertThatThrownBy(() -> service.vehicle("user-1", 7L))
                .isInstanceOf(ResponseStatusException.class)
                .hasMessageContaining("Not authorized");
    }

    @Test
    void returnsNearbyStationsNearestFirst() {
        ChargingStation near = station(new BigDecimal("18.5205"), new BigDecimal("73.8567"));
        ChargingStation far = station(new BigDecimal("18.7000"), new BigDecimal("74.0000"));
        when(stations.findByActiveTrue()).thenReturn(List.of(far, near));

        List<ChargingStation> result = service.nearby(18.5204, 73.8566, 5);

        assertThat(result).containsExactly(near);
    }

    @Test
    void rejectsInvalidNearbySearch() {
        assertThatThrownBy(() -> service.nearby(91, 73, 10))
                .isInstanceOf(ResponseStatusException.class)
                .hasMessageContaining("Invalid coordinates or radius");
        verify(stations, never()).findByActiveTrue();
    }

    private ChargingStation station(BigDecimal latitude, BigDecimal longitude) {
        ChargingStation station = new ChargingStation();
        station.setLatitude(latitude);
        station.setLongitude(longitude);
        station.setPowerKw(BigDecimal.ONE);
        station.setStationName("Test station");
        station.setActive(true);
        return station;
    }
}
