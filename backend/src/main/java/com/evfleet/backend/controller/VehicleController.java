
package com.evfleet.backend.controller;

import com.evfleet.backend.model.Vehicle;
import com.evfleet.backend.security.CurrentUser;
import com.evfleet.backend.service.VehicleService;

import jakarta.validation.Valid;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/vehicles")
public class VehicleController {

    private final VehicleService service;

    public VehicleController(VehicleService service) {
        this.service = service;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Vehicle create(
            Authentication auth,
            @Valid @RequestBody Vehicle body
    ) {
        return service.create(CurrentUser.subject(auth), body);
    }

    @GetMapping
    public List<Vehicle> list(Authentication auth) {
        return service.list(CurrentUser.subject(auth));
    }

    @GetMapping("/{id}")
    public Vehicle get(
            Authentication auth,
            @PathVariable Long id
    ) {
        return service.get(CurrentUser.subject(auth), id);
    }

    @PutMapping("/{id}")
    public Vehicle update(
            Authentication auth,
            @PathVariable Long id,
            @Valid @RequestBody Vehicle body
    ) {
        return service.update(
                CurrentUser.subject(auth),
                id,
                body
        );
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(
            Authentication auth,
            @PathVariable Long id
    ) {
        service.delete(CurrentUser.subject(auth), id);
    }
}
