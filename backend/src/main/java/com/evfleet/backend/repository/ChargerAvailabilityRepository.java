package com.evfleet.backend.repository;
import com.evfleet.backend.model.ChargerAvailability;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.Instant; import java.util.List;
public interface ChargerAvailabilityRepository extends JpaRepository<ChargerAvailability, Long> { List<ChargerAvailability> findByStationId(Long stationId); boolean existsByStationIdAndStartTimeLessThanAndEndTimeGreaterThan(Long stationId, Instant end, Instant start); }
