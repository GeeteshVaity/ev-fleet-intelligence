package com.evfleet.backend.service;

import com.evfleet.backend.model.Vehicle;
import org.springframework.stereotype.Service;
import java.util.List;

@Service
public class VehicleService {
    private final PlatformService platform;
    public VehicleService(PlatformService platform) { this.platform = platform; }
    public Vehicle create(String sub, Vehicle vehicle) { return platform.saveVehicle(sub, vehicle); }
    public List<Vehicle> list(String sub) { return platform.myVehicles(sub); }
    public Vehicle get(String sub, Long id) { return platform.vehicle(sub, id); }
    public Vehicle update(String sub, Long id, Vehicle vehicle) { return platform.updateVehicle(sub, id, vehicle); }
    public void delete(String sub, Long id) { platform.deleteVehicle(sub, id); }
}
