
package com.evfleet.backend.repository;

import com.evfleet.backend.model.Booking;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.Collection;
import java.util.List;

public interface BookingRepository extends JpaRepository<Booking, Long> {

    // Find all bookings created by a vehicle owner.
    List<Booking> findBySeekerUserId(Long userId);

    // Find all bookings associated with a charging station.
    List<Booking> findByStationId(Long stationId);

    // Check whether another booking overlaps the requested time.
    // Only statuses supplied by the service are considered.
    boolean existsByStationIdAndStatusInAndStartTimeLessThanAndEndTimeGreaterThan(
            Long stationId,
            Collection<String> statuses,
            Instant requestedEnd,
            Instant requestedStart
    );
}
