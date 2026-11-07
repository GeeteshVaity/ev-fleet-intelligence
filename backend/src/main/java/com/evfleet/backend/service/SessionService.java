
package com.evfleet.backend.service;

import com.evfleet.backend.model.ChargingSession;
import org.springframework.stereotype.Service;

@Service
public class SessionService {

    private final PlatformService platform;

    public SessionService(PlatformService platform) {
        this.platform = platform;
    }

    // Start a charging session for a confirmed booking.
    public ChargingSession start(String sub, Long bookingId) {
        return platform.startSession(sub, bookingId);
    }

    // Retrieve a session by its ID.
    public ChargingSession get(String sub, Long sessionId) {
        return platform.session(sub, sessionId);
    }

    // Complete a session and calculate its final bill.
    public ChargingSession complete(
            String sub,
            Long sessionId,
            ChargingSession session
    ) {
        return platform.completeSession(sub, sessionId, session);
    }

    // Recover a session using its associated booking ID.
    public ChargingSession getByBooking(String sub, Long bookingId) {
        return platform.sessionByBooking(sub, bookingId);
    }
}
