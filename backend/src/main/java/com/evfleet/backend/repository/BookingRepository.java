package com.evfleet.backend.repository;
import com.evfleet.backend.model.Booking;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.Instant; import java.util.*;
public interface BookingRepository extends JpaRepository<Booking, Long> {
 List<Booking> findBySeekerUserId(Long userId); List<Booking> findByStationId(Long stationId);
 boolean existsByStationIdAndStatusInAndStartTimeLessThanAndEndTimeGreaterThan(Long stationId, Collection<String> statuses, Instant end, Instant start);
}
