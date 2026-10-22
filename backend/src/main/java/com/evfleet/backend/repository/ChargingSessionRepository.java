package com.evfleet.backend.repository;
import com.evfleet.backend.model.ChargingSession;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;
public interface ChargingSessionRepository extends JpaRepository<ChargingSession, Long> { Optional<ChargingSession> findByBookingId(Long bookingId); }
