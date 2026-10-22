package com.evfleet.backend.service;

import com.evfleet.backend.model.StationImage;
import org.springframework.stereotype.Service;
import java.util.List;

@Service
public class StationImageService {
    private final PlatformService platform;
    public StationImageService(PlatformService platform) { this.platform = platform; }
    public List<StationImage> list(Long stationId) { return platform.images(stationId); }
    public StationImage add(String sub, Long stationId, StationImage image) { return platform.addImage(sub, stationId, image); }
    public void delete(String sub, Long stationId, Long imageId) { platform.deleteImage(sub, stationId, imageId); }
    public void authorizeUpload(String sub, Long stationId) { platform.stationBookings(sub, stationId); }
}
