package com.evfleet.backend.controller;

import com.evfleet.backend.model.StationImage;
import com.evfleet.backend.service.StationImageService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import java.util.*;
import org.springframework.security.core.Authentication;
import static com.evfleet.backend.security.CurrentUser.subject;

@RestController
@RequestMapping("/api/stations/{stationId}/images")
public class StationImageController {
    private final StationImageService service;
    public StationImageController(StationImageService service) { this.service = service; }
    @GetMapping public List<StationImage> list(@PathVariable Long stationId) { return service.list(stationId); }
    /**
     * Presigned S3 uploads are not configured on this deployment. The previous
     * implementation returned a locally invented URL, which made the client
     * believe an upload was possible. Answer honestly instead; the intended
     * contract is documented in docs/API.md.
     */
    @PostMapping("/upload-url") public Map<String, String> uploadUrl(Authentication auth, @PathVariable Long stationId, @RequestBody Map<String, String> body) {
        String sub = subject(auth);
        service.authorizeUpload(sub, stationId);
        throw new ResponseStatusException(HttpStatus.NOT_IMPLEMENTED,
                "Presigned S3 uploads are not configured on this deployment");
    }
    @PostMapping @ResponseStatus(HttpStatus.CREATED) public StationImage add(Authentication auth, @PathVariable Long stationId, @RequestBody StationImage body) { return service.add(subject(auth), stationId, body); }
    @DeleteMapping("/{imageId}") @ResponseStatus(HttpStatus.NO_CONTENT) public void delete(Authentication auth, @PathVariable Long stationId, @PathVariable Long imageId) { service.delete(subject(auth), stationId, imageId); }
}
