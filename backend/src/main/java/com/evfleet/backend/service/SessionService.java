package com.evfleet.backend.service;

import com.evfleet.backend.model.ChargingSession;
import org.springframework.stereotype.Service;

@Service
public class SessionService {
    private final PlatformService platform;
    public SessionService(PlatformService platform) { this.platform = platform; }
    public ChargingSession start(String sub, Long bookingId) { return platform.startSession(sub, bookingId); }
    public ChargingSession get(String sub, Long id) { return platform.session(sub, id); }
    public ChargingSession complete(String sub, Long id, ChargingSession session) { return platform.completeSession(sub, id, session); }
}
