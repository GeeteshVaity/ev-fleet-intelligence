package com.evfleet.backend.controller;

import com.evfleet.backend.model.*;
import com.evfleet.backend.service.PlatformService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import java.util.*;

@RestController
@RequestMapping("/api")
public class PlatformController {
    private final PlatformService service;
    public PlatformController(PlatformService service){this.service=service;}
    @PostMapping("/users/me") @ResponseStatus(HttpStatus.CREATED) public AppUser createProfile(@RequestHeader("X-User-Sub") String sub,@Valid @RequestBody AppUser body){return service.saveProfile(sub,body);}
    @GetMapping("/users/me") public AppUser profile(@RequestHeader("X-User-Sub") String sub){return service.current(sub);}
    @PutMapping("/users/me") public AppUser updateProfile(@RequestHeader("X-User-Sub") String sub,@Valid @RequestBody AppUser body){return service.saveProfile(sub,body);}
    @GetMapping("/users/me/vehicles") public List<Vehicle> myVehicles(@RequestHeader("X-User-Sub") String sub){return service.myVehicles(sub);}
    @GetMapping("/users/me/stations") public List<ChargingStation> myStations(@RequestHeader("X-User-Sub") String sub){return service.mine(sub);}
    @PostMapping("/vehicles") @ResponseStatus(HttpStatus.CREATED) public Vehicle addVehicle(@RequestHeader("X-User-Sub") String sub,@RequestBody Vehicle body){return service.saveVehicle(sub,body);}
    @GetMapping("/vehicles") public List<Vehicle> vehicles(@RequestHeader("X-User-Sub") String sub){return service.myVehicles(sub);}
    @GetMapping("/vehicles/{id}") public Vehicle vehicle(@RequestHeader("X-User-Sub") String sub,@PathVariable Long id){return service.vehicle(sub,id);}
    @PutMapping("/vehicles/{id}") public Vehicle updateVehicle(@RequestHeader("X-User-Sub") String sub,@PathVariable Long id,@RequestBody Vehicle body){return service.updateVehicle(sub,id,body);}
    @DeleteMapping("/vehicles/{id}") @ResponseStatus(HttpStatus.NO_CONTENT) public void deleteVehicle(@RequestHeader("X-User-Sub") String sub,@PathVariable Long id){service.deleteVehicle(sub,id);}
    @PostMapping("/stations") @ResponseStatus(HttpStatus.CREATED) public ChargingStation addStation(@RequestHeader("X-User-Sub") String sub,@RequestBody ChargingStation body){return service.saveStation(sub,body);}
    @GetMapping("/stations") public List<ChargingStation> stations(){return service.browse();}
    @GetMapping("/stations/nearby") public List<ChargingStation> nearby(@RequestParam double latitude,@RequestParam double longitude,@RequestParam double radiusKm){return service.nearby(latitude,longitude,radiusKm);}
    @GetMapping("/stations/mine") public List<ChargingStation> mine(@RequestHeader("X-User-Sub") String sub){return service.mine(sub);}
    @GetMapping("/stations/{id}") public ChargingStation station(@PathVariable Long id){return service.station(id);}
    @PutMapping("/stations/{id}") public ChargingStation updateStation(@RequestHeader("X-User-Sub") String sub,@PathVariable Long id,@RequestBody ChargingStation body){return service.updateStation(sub,id,body);}
    @DeleteMapping("/stations/{id}") @ResponseStatus(HttpStatus.NO_CONTENT) public void deleteStation(@RequestHeader("X-User-Sub") String sub,@PathVariable Long id){service.deactivateStation(sub,id);}
    @GetMapping("/stations/{id}/availability") public List<ChargerAvailability> windows(@PathVariable Long id){return service.windows(id);}
    @PostMapping("/stations/{id}/availability") @ResponseStatus(HttpStatus.CREATED) public ChargerAvailability addWindow(@RequestHeader("X-User-Sub") String sub,@PathVariable Long id,@RequestBody ChargerAvailability body){return service.addWindow(sub,id,body);}
    @PutMapping("/stations/{id}/availability/{windowId}") public ChargerAvailability updateWindow(@RequestHeader("X-User-Sub") String sub,@PathVariable Long id,@PathVariable Long windowId,@RequestBody ChargerAvailability body){return service.updateWindow(sub,id,windowId,body);}
    @DeleteMapping("/stations/{id}/availability/{windowId}") @ResponseStatus(HttpStatus.NO_CONTENT) public void deleteWindow(@RequestHeader("X-User-Sub") String sub,@PathVariable Long id,@PathVariable Long windowId){service.deleteWindow(sub,id,windowId);}
    @PostMapping("/bookings") @ResponseStatus(HttpStatus.CREATED) public Booking createBooking(@RequestHeader("X-User-Sub") String sub,@RequestBody Booking body){return service.createBooking(sub,body);}
    @GetMapping("/bookings") public List<Booking> bookings(@RequestHeader("X-User-Sub") String sub){return service.bookings(sub);}
    @GetMapping("/bookings/{id}") public Booking booking(@RequestHeader("X-User-Sub") String sub,@PathVariable Long id){return service.booking(sub,id);}
    @PutMapping("/bookings/{id}/cancel") public Booking cancel(@RequestHeader("X-User-Sub") String sub,@PathVariable Long id){return service.transition(sub,id,"CANCELLED");}
    @PutMapping("/bookings/{id}/confirm") public Booking confirm(@RequestHeader("X-User-Sub") String sub,@PathVariable Long id){return service.transition(sub,id,"CONFIRMED");}
    @PutMapping("/bookings/{id}/reject") public Booking reject(@RequestHeader("X-User-Sub") String sub,@PathVariable Long id){return service.transition(sub,id,"REJECTED");}
    @GetMapping("/stations/{id}/bookings") public List<Booking> stationBookings(@RequestHeader("X-User-Sub") String sub,@PathVariable Long id){return service.stationBookings(sub,id);}
    @PostMapping("/bookings/{id}/sessions") @ResponseStatus(HttpStatus.CREATED) public ChargingSession start(@RequestHeader("X-User-Sub") String sub,@PathVariable Long id){return service.startSession(sub,id);}
    @GetMapping("/sessions/{id}") public ChargingSession session(@RequestHeader("X-User-Sub") String sub,@PathVariable Long id){return service.session(sub,id);}
    @PutMapping("/sessions/{id}/complete") public ChargingSession complete(@RequestHeader("X-User-Sub") String sub,@PathVariable Long id,@RequestBody ChargingSession body){return service.completeSession(sub,id,body);}
    @GetMapping("/users/me/sessions") public List<ChargingSession> sessions(@RequestHeader("X-User-Sub") String sub){return service.mySessions(sub);}
    @GetMapping("/stations/{id}/images") public List<StationImage> images(@PathVariable Long id){return service.images(id);}
    @PostMapping("/stations/{id}/images/upload-url") public Map<String,String> uploadUrl(@RequestHeader("X-User-Sub") String sub,@PathVariable Long id,@RequestBody Map<String,String> body){service.stationBookings(sub,id);String key=UUID.randomUUID()+"-"+body.getOrDefault("fileName","image");return Map.of("uploadUrl","/api/stations/"+id+"/images","s3ObjectKey",key,"note","Configure S3 presigned URLs before production");}
    @PostMapping("/stations/{id}/images") @ResponseStatus(HttpStatus.CREATED) public StationImage addImage(@RequestHeader("X-User-Sub") String sub,@PathVariable Long id,@RequestBody StationImage body){return service.addImage(sub,id,body);}
    @DeleteMapping("/stations/{id}/images/{imageId}") @ResponseStatus(HttpStatus.NO_CONTENT) public void deleteImage(@RequestHeader("X-User-Sub") String sub,@PathVariable Long id,@PathVariable Long imageId){service.deleteImage(sub,id,imageId);}
}
