
package com.evfleet.backend.repository;

import com.evfleet.backend.model.ChargerAvailability;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.List;

public interface ChargerAvailabilityRepository
        extends JpaRepository<ChargerAvailability, Long> {

    // Find all availability windows belonging to a station.
    List<ChargerAvailability> findByStationId(Long stationId);

    // Check whether a new availability window overlaps an existing window.
    boolean existsByStationIdAndStartTimeLessThanAndEndTimeGreaterThan(
            Long stationId,
            Instant end,
            Instant start
    );

    // Check for overlapping windows while excluding the window being updated.
    boolean existsByStationIdAndIdNotAndStartTimeLessThanAndEndTimeGreaterThan(
            Long stationId,
            Long id,
            Instant end,
            Instant start
    );

    // Verify that an AVAILABLE window completely contains a requested booking.
    boolean existsByStationIdAndStatusAndStartTimeLessThanEqualAndEndTimeGreaterThanEqual(
            Long stationId,
            String status,
            Instant requestedStart,
            Instant requestedEnd
    );
}
