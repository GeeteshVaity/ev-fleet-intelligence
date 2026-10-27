package com.evfleet.backend.controller;

import com.evfleet.backend.model.Vehicle;
import com.evfleet.backend.service.VehicleService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.security.core.Authentication;
import static com.evfleet.backend.security.CurrentUser.subject;

@RestController
@RequestMapping("/api/vehicles")
public class VehicleController {
    private final VehicleService service;
    public VehicleController(VehicleService service) { this.service = service; }
    @PostMapping @ResponseStatus(HttpStatus.CREATED) public Vehicle create(Authentication auth, @Valid @RequestBody Vehicle body) { return service.create(subject(auth), body); }
    @GetMapping public List<Vehicle> list(Authentication auth) { return service.list(subject(auth)); }
    @GetMapping("/{id}") public Vehicle get(Authentication auth, @PathVariable Long id) { return service.get(subject(auth), id); }
    @PutMapping("/{id}") public Vehicle update(Authentication auth, @PathVariable Long id, @Valid @RequestBody Vehicle body) { return service.update(subject(auth), id, body); }
    @DeleteMapping("/{id}") @ResponseStatus(HttpStatus.NO_CONTENT) public void delete(Authentication auth, @PathVariable Long id) { service.delete(subject(auth), id); }
}
