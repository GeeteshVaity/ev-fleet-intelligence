package com.evfleet.backend.controller;

import com.evfleet.backend.model.Vehicle;
import com.evfleet.backend.service.VehicleService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import jakarta.validation.Valid;
import java.util.List;

@RestController
@RequestMapping("/api/vehicles")
public class VehicleController {
    private final VehicleService service;
    public VehicleController(VehicleService service) { this.service = service; }
    @PostMapping @ResponseStatus(HttpStatus.CREATED) public Vehicle create(@RequestHeader("X-User-Sub") String sub, @Valid @RequestBody Vehicle body) { return service.create(sub, body); }
    @GetMapping public List<Vehicle> list(@RequestHeader("X-User-Sub") String sub) { return service.list(sub); }
    @GetMapping("/{id}") public Vehicle get(@RequestHeader("X-User-Sub") String sub, @PathVariable Long id) { return service.get(sub, id); }
    @PutMapping("/{id}") public Vehicle update(@RequestHeader("X-User-Sub") String sub, @PathVariable Long id, @Valid @RequestBody Vehicle body) { return service.update(sub, id, body); }
    @DeleteMapping("/{id}") @ResponseStatus(HttpStatus.NO_CONTENT) public void delete(@RequestHeader("X-User-Sub") String sub, @PathVariable Long id) { service.delete(sub, id); }
}
