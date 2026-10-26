package com.evfleet.backend.service;

import com.evfleet.backend.model.*;
import com.evfleet.backend.repository.*;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.*;

@Service
public class PlatformService {
    private final AppUserRepository users;
    private final VehicleRepository vehicles;
    private final ChargingStationRepository stations;
    private final BookingRepository bookings;
    private final ChargingSessionRepository sessions;
    private final ChargerAvailabilityRepository availability;
    private final StationImageRepository images;

    public PlatformService(AppUserRepository users, VehicleRepository vehicles, ChargingStationRepository stations,
                           BookingRepository bookings, ChargingSessionRepository sessions,
                           ChargerAvailabilityRepository availability, StationImageRepository images) {
        this.users=users; this.vehicles=vehicles; this.stations=stations; this.bookings=bookings;
        this.sessions=sessions; this.availability=availability; this.images=images;
    }
    public AppUser current(String sub) {
        if (sub == null || sub.isBlank()) throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "X-User-Sub is required");
        return users.findByCognitoSub(sub).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Profile not found"));
    }
    public AppUser saveProfile(String sub, AppUser input) {
        AppUser user=users.findByCognitoSub(sub).orElseGet(AppUser::new);
        user.setCognitoSub(sub); user.setFullName(input.getFullName()); user.setEmail(input.getEmail()); user.setPhone(input.getPhone()); user.touch();
        return users.save(user);
    }
    public AppUser updateOnboarding(String sub, String role, Boolean completed, Integer step) {
        AppUser user = current(sub);
        if (role != null && !role.equals("VEHICLE_OWNER") && !role.equals("CHARGER_PROVIDER")) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "role must be VEHICLE_OWNER or CHARGER_PROVIDER");
        }
        if (user.getRole() != null && role != null && !user.getRole().equals(role)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Role cannot be changed after registration");
        }
        if (role != null) user.setRole(role);
        if (completed != null) user.setOnboardingCompleted(completed);
        if (step != null && step < 1) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "onboardingStep must be positive");
        user.setOnboardingStep(step);
        user.touch();
        return users.save(user);
    }
    public List<Vehicle> myVehicles(String sub){ return vehicles.findByOwnerUserId(current(sub).getId()); }
    public Vehicle vehicle(String sub, Long id){ return ownedVehicle(sub,id); }
    public Vehicle saveVehicle(String sub, Vehicle input){ requireRole(sub, "VEHICLE_OWNER"); input.setOwnerUserId(current(sub).getId()); input.setVehicleType(required(input.getVehicleType(),"vehicleType")); input.setModel(required(input.getModel(),"model")); return vehicles.save(input); }
    public Vehicle updateVehicle(String sub, Long id, Vehicle input){ Vehicle v=ownedVehicle(sub,id); v.setVehicleType(required(input.getVehicleType(),"vehicleType")); v.setBrand(input.getBrand()); v.setModel(required(input.getModel(),"model")); v.setRegistrationNumber(input.getRegistrationNumber()); v.setBatteryCapacityKwh(input.getBatteryCapacityKwh()); v.setConnectorType(input.getConnectorType()); return vehicles.save(v); }
    public void deleteVehicle(String sub, Long id){ vehicles.delete(ownedVehicle(sub,id)); }
    private Vehicle ownedVehicle(String sub, Long id){ Vehicle v=vehicles.findById(id).orElseThrow(()->notFound("Vehicle")); if(!v.getOwnerUserId().equals(current(sub).getId())) throw forbidden(); return v; }

    public List<ChargingStation> browse(){ return stations.findByActiveTrue(); }
    public List<ChargingStation> mine(String sub){ return stations.findByOwnerUserId(current(sub).getId()); }
    public ChargingStation station(Long id){ return stations.findById(id).filter(ChargingStation::isActive).orElseThrow(()->notFound("Station")); }
    public ChargingStation saveStation(String sub, ChargingStation input){ requireRole(sub, "CHARGER_PROVIDER"); input.setOwnerUserId(current(sub).getId()); validateCoordinates(input); return stations.save(input); }
    public ChargingStation updateStation(String sub, Long id, ChargingStation input){ ChargingStation s=ownedStation(sub,id); input.setOwnerUserId(s.getOwnerUserId()); input.setActive(s.isActive()); validateCoordinates(input); return copyStation(s,input); }
    public void deactivateStation(String sub, Long id){ ChargingStation s=ownedStation(sub,id); s.setActive(false); stations.save(s); }
    private ChargingStation ownedStation(String sub,Long id){ ChargingStation s=stations.findById(id).orElseThrow(()->notFound("Station")); if(!Objects.equals(s.getOwnerUserId(),current(sub).getId())) throw forbidden(); return s; }
    private void requireRole(String sub, String required) {
        AppUser user = current(sub);
        // Existing records may predate role selection; keep their current
        // access until an explicit migration assigns a role.
        if (user.getRole() != null && !required.equals(user.getRole())) throw forbidden();
    }
    private ChargingStation copyStation(ChargingStation s,ChargingStation i){s.setStationName(i.getStationName());s.setProviderType(i.getProviderType());s.setAccessType(i.getAccessType());s.setAddress(i.getAddress());s.setLatitude(i.getLatitude());s.setLongitude(i.getLongitude());s.setConnectorType(i.getConnectorType());s.setPowerKw(i.getPowerKw());s.setPricePerKwh(i.getPricePerKwh());return stations.save(s);}
    public List<ChargingStation> nearby(double lat,double lon,double radius){ if(lat<-90||lat>90||lon<-180||lon>180||radius<=0) throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Invalid coordinates or radius"); return browse().stream().filter(s->distance(lat,lon,s.getLatitude().doubleValue(),s.getLongitude().doubleValue())<=radius).sorted(Comparator.comparingDouble(s->distance(lat,lon,s.getLatitude().doubleValue(),s.getLongitude().doubleValue()))).toList(); }
    private double distance(double a,double b,double c,double d){double x=Math.toRadians(c-a),y=Math.toRadians(d-b);double h=Math.sin(x/2)*Math.sin(x/2)+Math.cos(Math.toRadians(a))*Math.cos(Math.toRadians(c))*Math.sin(y/2)*Math.sin(y/2);return 6371*2*Math.atan2(Math.sqrt(h),Math.sqrt(1-h));}
    private void validateCoordinates(ChargingStation s){if(s.getLatitude()==null||s.getLongitude()==null||s.getLatitude().doubleValue()<-90||s.getLatitude().doubleValue()>90||s.getLongitude().doubleValue()<-180||s.getLongitude().doubleValue()>180)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Invalid coordinates");if(s.getPowerKw()==null||s.getPowerKw().signum()<=0)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"powerKw must be positive");}

    public List<ChargerAvailability> windows(Long id){station(id);return availability.findByStationId(id);}
    public ChargerAvailability addWindow(String sub,Long id,ChargerAvailability w){ownedStation(sub,id);validTimes(w.getStartTime(),w.getEndTime());w.setStationId(id);if(availability.existsByStationIdAndStartTimeLessThanAndEndTimeGreaterThan(id,w.getEndTime(),w.getStartTime()))throw conflict("Availability overlaps");return availability.save(w);}
    public ChargerAvailability updateWindow(String sub,Long id,Long wid,ChargerAvailability w){ownedStation(sub,id);ChargerAvailability old=availability.findById(wid).orElseThrow(()->notFound("Availability"));if(!old.getStationId().equals(id))throw notFound("Availability");validTimes(w.getStartTime(),w.getEndTime());old.setStartTime(w.getStartTime());old.setEndTime(w.getEndTime());old.setStatus(w.getStatus());return availability.save(old);}
    public void deleteWindow(String sub,Long id,Long wid){ownedStation(sub,id);availability.delete(availability.findById(wid).filter(w->w.getStationId().equals(id)).orElseThrow(()->notFound("Availability")));}

    @Transactional public Booking createBooking(String sub,Booking b){AppUser u=current(sub); Vehicle vehicle=ownedVehicle(sub,b.getVehicleId());ChargingStation s=station(b.getStationId());validTimes(b.getStartTime(),b.getEndTime());if(vehicle.getConnectorType()!=null&&!vehicle.getConnectorType().isBlank()&&!vehicle.getConnectorType().equalsIgnoreCase(s.getConnectorType()))throw conflict("Vehicle connector is incompatible with station");if(!availability.existsByStationIdAndStartTimeLessThanAndEndTimeGreaterThan(s.getId(),b.getEndTime(),b.getStartTime()))throw conflict("Requested time is not available");if(bookings.existsByStationIdAndStatusInAndStartTimeLessThanAndEndTimeGreaterThan(s.getId(),List.of("PENDING","CONFIRMED"),b.getEndTime(),b.getStartTime()))throw conflict("Station is already booked");b.setSeekerUserId(u.getId());b.setStatus("PENDING");if(s.getPricePerKwh()!=null)b.setEstimatedCost(s.getPricePerKwh());return bookings.save(b);}
    public List<Booking> bookings(String sub){return bookings.findBySeekerUserId(current(sub).getId());}
    public Booking booking(String sub,Long id){Booking b=bookings.findById(id).orElseThrow(()->notFound("Booking"));AppUser u=current(sub);if(!Objects.equals(b.getSeekerUserId(),u.getId())&&!Objects.equals(stations.findById(b.getStationId()).map(ChargingStation::getOwnerUserId).orElse(null),u.getId()))throw forbidden();return b;}
    public Booking transition(String sub,Long id,String status){Booking b=booking(sub,id);if(!b.getStatus().equals("PENDING"))throw conflict("Booking is not pending");b.setStatus(status);return bookings.save(b);}
    public List<Booking> stationBookings(String sub,Long id){ownedStation(sub,id);return bookings.findByStationId(id);}

    @Transactional public ChargingSession startSession(String sub,Long bookingId){Booking b=booking(sub,bookingId);if(!b.getStatus().equals("CONFIRMED"))throw conflict("Booking must be confirmed");if(sessions.findByBookingId(bookingId).isPresent())throw conflict("Session already exists");ChargingSession s=new ChargingSession();s.setBookingId(bookingId);s.setActualStartTime(Instant.now());return sessions.save(s);}
    public ChargingSession session(String sub,Long id){ChargingSession s=sessions.findById(id).orElseThrow(()->notFound("Session"));booking(sub,s.getBookingId());return s;}
    public ChargingSession completeSession(String sub,Long id,ChargingSession input){ChargingSession s=session(sub,id);if(!s.getStatus().equals("IN_PROGRESS"))throw conflict("Session is not active");if(input.getEnergyConsumedKwh()==null||input.getEnergyConsumedKwh().signum()<0)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"energyConsumedKwh must be non-negative");s.setEnergyConsumedKwh(input.getEnergyConsumedKwh());s.setFinalCost(input.getFinalCost());s.setActualEndTime(Instant.now());s.setStatus("COMPLETED");return sessions.save(s);}
    public List<ChargingSession> mySessions(String sub){return bookings(sub).stream().map(Booking::getId).flatMap(id->sessions.findByBookingId(id).stream()).toList();}
    public List<StationImage> images(Long id){station(id);return images.findByStationId(id);}
    public StationImage addImage(String sub,Long id,StationImage input){ownedStation(sub,id);if(input.getS3ObjectKey()==null||input.getS3ObjectKey().isBlank())throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"s3ObjectKey is required");input.setStationId(id);return images.save(input);}
    public void deleteImage(String sub,Long id,Long imageId){ownedStation(sub,id);images.delete(images.findById(imageId).filter(i->i.getStationId().equals(id)).orElseThrow(()->notFound("Image")));}
    private void validTimes(Instant a,Instant b){if(a==null||b==null||!b.isAfter(a))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"endTime must be after startTime");}
    private String required(String v,String name){if(v==null||v.isBlank())throw new ResponseStatusException(HttpStatus.BAD_REQUEST,name+" is required");return v;}
    private ResponseStatusException notFound(String x){return new ResponseStatusException(HttpStatus.NOT_FOUND,x+" not found");}
    private ResponseStatusException forbidden(){return new ResponseStatusException(HttpStatus.FORBIDDEN,"Not authorized");}
    private ResponseStatusException conflict(String x){return new ResponseStatusException(HttpStatus.CONFLICT,x);}
}
