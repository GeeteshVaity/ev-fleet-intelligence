package com.evfleet.backend.service;

import com.evfleet.backend.model.AppUser;
import com.evfleet.backend.model.ChargingStation;
import com.evfleet.backend.model.Vehicle;
import org.springframework.stereotype.Service;
import java.util.List;

@Service
public class UserService {
    private final PlatformService platform;
    public UserService(PlatformService platform) { this.platform = platform; }
    public AppUser createOrUpdate(String sub, AppUser user) { return platform.saveProfile(sub, user); }
    public AppUser current(String sub) { return platform.current(sub); }
    public AppUser updateOnboarding(String sub, String role, Boolean completed, Integer step) {
        return platform.updateOnboarding(sub, role, completed, step);
    }
    public List<Vehicle> vehicles(String sub) { return platform.myVehicles(sub); }
    public List<ChargingStation> stations(String sub) { return platform.mine(sub); }
    public List<com.evfleet.backend.model.ChargingSession> sessions(String sub) { return platform.mySessions(sub); }
}
