package com.evfleet.backend.service;

import com.evfleet.backend.model.AppUser;
import com.evfleet.backend.model.ChargingStation;
import com.evfleet.backend.model.Vehicle;
import com.evfleet.backend.model.Booking;
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
import java.time.Instant;

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
    void rejectsNonexistentVehicle() {
        when(vehicles.findById(404L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.vehicle("user-1", 404L))
                .isInstanceOf(ResponseStatusException.class)
                .hasMessageContaining("Vehicle not found");
    }

    @Test
    void rejectsStationUpdateForAnotherOwner() {
        setId(user, 1L);
        ChargingStation station = station(new BigDecimal("18.5204"), new BigDecimal("73.8567"));
        station.setOwnerUserId(2L);
        when(stations.findById(8L)).thenReturn(Optional.of(station));

        assertThatThrownBy(() -> service.updateStation("user-1", 8L, station))
                .isInstanceOf(ResponseStatusException.class)
                .hasMessageContaining("Not authorized");
        verify(stations, never()).save(any());
    }

    @Test
    void rejectsBookingReadForAnotherUser() {
        setId(user, 1L);
        Booking booking = booking(7L, 8L);
        booking.setSeekerUserId(2L);
        ChargingStation station = station(new BigDecimal("18.5204"), new BigDecimal("73.8567"));
        station.setOwnerUserId(3L);
        when(bookings.findById(9L)).thenReturn(Optional.of(booking));
        when(stations.findById(8L)).thenReturn(Optional.of(station));

        assertThatThrownBy(() -> service.booking("user-1", 9L))
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

    @Test
    void rejectsBookingWhenConnectorIsIncompatible() {
        setId(user, 1L);
        Vehicle vehicle = new Vehicle();
        vehicle.setOwnerUserId(1L);
        vehicle.setConnectorType("CCS");
        setId(vehicle, 7L);
        ChargingStation station = station(new BigDecimal("18.5204"), new BigDecimal("73.8567"));
        station.setConnectorType("TYPE_2");
        setId(station, 8L);
        when(vehicles.findById(7L)).thenReturn(Optional.of(vehicle));
        when(stations.findById(8L)).thenReturn(Optional.of(station));
        Booking booking = booking(7L, 8L);

        assertThatThrownBy(() -> service.createBooking("user-1", booking))
                .isInstanceOf(ResponseStatusException.class)
                .hasMessageContaining("incompatible");
        verifyNoInteractions(availability, bookings);
    }

    @Test
    void rejectsBookingWhenSlotIsAlreadyBooked() {
        setId(user, 1L);
        Vehicle vehicle = new Vehicle();
        vehicle.setOwnerUserId(1L);
        vehicle.setConnectorType("TYPE_2");
        setId(vehicle, 7L);
        ChargingStation station = station(new BigDecimal("18.5204"), new BigDecimal("73.8567"));
        station.setConnectorType("TYPE_2");
        setId(station, 8L);
        when(vehicles.findById(7L)).thenReturn(Optional.of(vehicle));
        when(stations.findById(8L)).thenReturn(Optional.of(station));
        when(availability.existsByStationIdAndStartTimeLessThanAndEndTimeGreaterThan(any(), any(), any())).thenReturn(true);
        when(bookings.existsByStationIdAndStatusInAndStartTimeLessThanAndEndTimeGreaterThan(any(), any(), any(), any())).thenReturn(true);

        assertThatThrownBy(() -> service.createBooking("user-1", booking(7L, 8L)))
                .isInstanceOf(ResponseStatusException.class)
                .hasMessageContaining("already booked");
        verify(bookings, never()).save(any());
    }

    private Booking booking(Long vehicleId, Long stationId) {
        Booking booking = new Booking();
        booking.setVehicleId(vehicleId);
        booking.setStationId(stationId);
        booking.setStartTime(Instant.parse("2026-10-22T10:00:00Z"));
        booking.setEndTime(Instant.parse("2026-10-22T11:00:00Z"));
        return booking;
    }

    private void setId(Object entity, Long id) {
        try {
            var field = entity.getClass().getDeclaredField("id");
            field.setAccessible(true);
            field.set(entity, id);
        } catch (ReflectiveOperationException exception) {
            throw new AssertionError(exception);
        }
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
