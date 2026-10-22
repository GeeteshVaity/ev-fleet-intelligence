package com.evfleet.backend.controller;

import com.evfleet.backend.model.StationImage;
import com.evfleet.backend.service.StationImageService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import java.util.*;

@RestController
@RequestMapping("/api/stations/{stationId}/images")
public class StationImageController {
    private final StationImageService service;
    public StationImageController(StationImageService service) { this.service = service; }
    @GetMapping public List<StationImage> list(@PathVariable Long stationId) { return service.list(stationId); }
    @PostMapping("/upload-url") public Map<String, String> uploadUrl(@RequestHeader("X-User-Sub") String sub, @PathVariable Long stationId, @RequestBody Map<String, String> body) {
        service.authorizeUpload(sub, stationId);
        String key = UUID.randomUUID() + "-" + body.getOrDefault("fileName", "image");
        return Map.of("uploadUrl", "/api/stations/" + stationId + "/images", "s3ObjectKey", key, "note", "Configure S3 presigned URLs before production");
    }
    @PostMapping @ResponseStatus(HttpStatus.CREATED) public StationImage add(@RequestHeader("X-User-Sub") String sub, @PathVariable Long stationId, @RequestBody StationImage body) { return service.add(sub, stationId, body); }
    @DeleteMapping("/{imageId}") @ResponseStatus(HttpStatus.NO_CONTENT) public void delete(@RequestHeader("X-User-Sub") String sub, @PathVariable Long stationId, @PathVariable Long imageId) { service.delete(sub, stationId, imageId); }
}
