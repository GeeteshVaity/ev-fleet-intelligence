package com.evfleet.backend.repository;

import com.evfleet.backend.model.AppUser;
import com.evfleet.backend.model.ChargingStation;
import com.evfleet.backend.model.Vehicle;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
@ActiveProfiles("test")
class RepositoryIntegrationTest {
    @Autowired private AppUserRepository users;
    @Autowired private VehicleRepository vehicles;
    @Autowired private ChargingStationRepository stations;

    @Test
    void persistsUserVehicleAndStationOwnership() {
        AppUser user = new AppUser();
        user.setCognitoSub("integration-user");
        user.setFullName("Integration User");
        user.setEmail("integration@example.com");
        user = users.saveAndFlush(user);

        Vehicle vehicle = new Vehicle();
        vehicle.setOwnerUserId(user.getId());
        vehicle.setVehicleType("CAR");
        vehicle.setModel("Model 3");
        vehicles.saveAndFlush(vehicle);

        ChargingStation station = new ChargingStation();
        station.setOwnerUserId(user.getId());
        station.setStationName("Integration Charger");
        station.setProviderType("HOUSEHOLD");
        station.setAccessType("PUBLIC");
        station.setAddress("Campus");
        station.setLatitude(new BigDecimal("18.5204"));
        station.setLongitude(new BigDecimal("73.8567"));
        station.setConnectorType("TYPE_2");
        station.setPowerKw(new BigDecimal("7.20"));
        stations.saveAndFlush(station);

        assertThat(users.findByCognitoSub("integration-user")).isPresent();
        assertThat(vehicles.findByOwnerUserId(user.getId())).hasSize(1);
        assertThat(stations.findByOwnerUserId(user.getId())).hasSize(1);
    }
}
