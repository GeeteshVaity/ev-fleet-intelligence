package com.evfleet.backend.repository;
import com.evfleet.backend.model.ChargingStation;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
public interface ChargingStationRepository extends JpaRepository<ChargingStation, Long> { List<ChargingStation> findByActiveTrue(); List<ChargingStation> findByOwnerUserId(Long ownerUserId); }
