package com.evfleet.backend.repository;
import com.evfleet.backend.model.ChargerAvailability;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.Instant; import java.util.List;
public interface ChargerAvailabilityRepository extends JpaRepository<ChargerAvailability, Long> {
    List<ChargerAvailability> findByStationId(Long stationId);
    boolean existsByStationIdAndStartTimeLessThanAndEndTimeGreaterThan(Long stationId, Instant end, Instant start);
    /** Used when updating a window so it does not overlap the provider's other windows. */
    boolean existsByStationIdAndIdNotAndStartTimeLessThanAndEndTimeGreaterThan(Long stationId, Long id, Instant end, Instant start);
}
