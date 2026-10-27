package com.evfleet.backend.service;

import com.evfleet.backend.model.ChargingStation;
import com.evfleet.backend.model.ChargerAvailability;
import org.springframework.stereotype.Service;
import java.util.List;

@Service
public class StationService {
    private final PlatformService platform;
    public StationService(PlatformService platform) { this.platform = platform; }
    public ChargingStation create(String sub, ChargingStation station) { return platform.saveStation(sub, station); }
    public List<ChargingStation> list() { return platform.browse(); }
    public List<ChargingStation> nearby(double latitude, double longitude, double radiusKm) { return platform.nearby(latitude, longitude, radiusKm); }
    public List<ChargingStation> mine(String sub) { return platform.mine(sub); }
    public ChargingStation get(Long id) { return platform.station(id); }
    public ChargingStation update(String sub, Long id, ChargingStation station) { return platform.updateStation(sub, id, station); }
    public ChargingStation setActive(String sub, Long id, boolean active) { return platform.setStationActive(sub, id, active); }
    public void deactivate(String sub, Long id) { platform.deactivateStation(sub, id); }
    public List<ChargerAvailability> availability(Long id) { return platform.windows(id); }
    public ChargerAvailability addAvailability(String sub, Long id, ChargerAvailability window) { return platform.addWindow(sub, id, window); }
    public ChargerAvailability updateAvailability(String sub, Long id, Long windowId, ChargerAvailability window) { return platform.updateWindow(sub, id, windowId, window); }
    public void deleteAvailability(String sub, Long id, Long windowId) { platform.deleteWindow(sub, id, windowId); }
}
