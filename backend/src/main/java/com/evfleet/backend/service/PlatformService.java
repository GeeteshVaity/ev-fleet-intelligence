
package com.evfleet.backend.service;

import com.evfleet.backend.controller.UserController;
import com.evfleet.backend.model.*;
import com.evfleet.backend.repository.*;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Duration;
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

    private static final double MAX_SEARCH_RADIUS_KM = 50;

    public PlatformService(
            AppUserRepository users,
            VehicleRepository vehicles,
            ChargingStationRepository stations,
            BookingRepository bookings,
            ChargingSessionRepository sessions,
            ChargerAvailabilityRepository availability,
            StationImageRepository images
    ) {
        this.users = users;
        this.vehicles = vehicles;
        this.stations = stations;
        this.bookings = bookings;
        this.sessions = sessions;
        this.availability = availability;
        this.images = images;
    }

    // --------------------------------------------------
    // USER PROFILE
    // --------------------------------------------------

    public AppUser current(String sub) {
        if (sub == null || sub.isBlank()) {
            throw new ResponseStatusException(
                    HttpStatus.UNAUTHORIZED,
                    "Authenticated Cognito subject is required"
            );
        }

        return users.findByCognitoSub(sub)
                .orElseThrow(() -> notFound("Profile"));
    }

    @Transactional
    public AppUser saveProfile(
            String sub,
            UserController.ProfileRequest input
    ) {
        if (sub == null || sub.isBlank()) {
            throw new ResponseStatusException(
                    HttpStatus.UNAUTHORIZED,
                    "Authenticated Cognito subject is required"
            );
        }

        AppUser user = users.findByCognitoSub(sub)
                .orElseGet(AppUser::new);

        user.setCognitoSub(sub);
        user.setFullName(input.fullName().trim());
        user.setEmail(input.email().trim().toLowerCase());
        user.setPhone(input.phone());

        if (input.role() != null) {
            validateRole(input.role());

            if (user.getRole() != null
                    && !user.getRole().equals(input.role())) {
                throw new ResponseStatusException(
                        HttpStatus.CONFLICT,
                        "Role cannot be changed after registration"
                );
            }

            user.setRole(input.role());
        }

        if (input.businessName() != null
                || input.providerType() != null
                || input.address() != null) {
            if (input.businessName() == null
                    || input.businessName().isBlank()
                    || input.providerType() == null
                    || input.providerType().isBlank()
                    || input.address() == null
                    || input.address().isBlank()) {
                throw new ResponseStatusException(
                        HttpStatus.BAD_REQUEST,
                        "Business name, provider type and address are required together"
                );
            }

            validateProviderType(input.providerType());

            user.setBusinessName(input.businessName().trim());
            user.setProviderType(input.providerType());
            user.setAddress(input.address().trim());
        }

        user.touch();
        return users.save(user);
    }

    private void validateProviderType(String providerType) {
        if (!List.of(
                "COMMERCIAL_PROPERTY",
                "RESIDENTIAL_HOST",
                "FLEET_OPERATOR",
                "HOUSEHOLD",
                "PUBLIC"
        ).contains(providerType)) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "Invalid provider type"
            );
        }
    }

    private void validateRole(String role) {
        if (!"VEHICLE_OWNER".equals(role)
                && !"CHARGER_PROVIDER".equals(role)) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "role must be VEHICLE_OWNER or CHARGER_PROVIDER"
            );
        }
    }

    @Transactional
    public AppUser updateOnboarding(
            String sub,
            String role,
            Boolean completed,
            Integer step
    ) {
        AppUser user = current(sub);

        if (role != null) {
            validateRole(role);
        }

        if (user.getRole() != null
                && role != null
                && !user.getRole().equals(role)) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT,
                    "Role cannot be changed after registration"
            );
        }

        if (role != null) {
            user.setRole(role);
        }

        if (Boolean.TRUE.equals(completed)) {
            String effectiveRole = user.getRole();

            if (effectiveRole == null) {
                throw new ResponseStatusException(
                        HttpStatus.BAD_REQUEST,
                        "role is required to complete onboarding"
                );
            }

            boolean hasRecords = "VEHICLE_OWNER".equals(effectiveRole)
                    ? !vehicles.findByOwnerUserId(user.getId()).isEmpty()
                    : !stations.findByOwnerUserId(user.getId()).isEmpty();

            if (!hasRecords) {
                throw new ResponseStatusException(
                        HttpStatus.BAD_REQUEST,
                        "Create at least one "
                                + ("VEHICLE_OWNER".equals(effectiveRole)
                                ? "vehicle" : "station")
                                + " before completing onboarding"
                );
            }

            if ("CHARGER_PROVIDER".equals(effectiveRole)
                    && (user.getBusinessName() == null
                    || user.getBusinessName().isBlank()
                    || user.getProviderType() == null
                    || user.getProviderType().isBlank()
                    || user.getAddress() == null
                    || user.getAddress().isBlank())) {
                throw new ResponseStatusException(
                                HttpStatus.BAD_REQUEST,
                                "Complete the provider profile before completing onboarding"
                );
            }
        }

        if (completed != null) {
            user.setOnboardingCompleted(completed);
        }

        if (step != null && step < 1) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "onboardingStep must be positive"
            );
        }

        if (step != null) {
            user.setOnboardingStep(step);
        }

        user.touch();
        return users.save(user);
    }

    // --------------------------------------------------
    // VEHICLES
    // --------------------------------------------------

    public List<Vehicle> myVehicles(String sub) {
        return vehicles.findByOwnerUserId(current(sub).getId());
    }

    public Vehicle vehicle(String sub, Long id) {
        return ownedVehicle(sub, id);
    }

    public Vehicle saveVehicle(String sub, Vehicle input) {
        requireRole(sub, "VEHICLE_OWNER");

        input.setOwnerUserId(current(sub).getId());
        input.setVehicleType(required(input.getVehicleType(), "vehicleType"));
        input.setModel(required(input.getModel(), "model"));

        return vehicles.save(input);
    }

    public Vehicle updateVehicle(
            String sub,
            Long id,
            Vehicle input
    ) {
        requireRole(sub, "VEHICLE_OWNER");
        Vehicle vehicle = ownedVehicle(sub, id);

        vehicle.setVehicleType(required(input.getVehicleType(), "vehicleType"));
        vehicle.setBrand(input.getBrand());
        vehicle.setModel(required(input.getModel(), "model"));
        vehicle.setRegistrationNumber(input.getRegistrationNumber());
        vehicle.setBatteryCapacityKwh(input.getBatteryCapacityKwh());
        vehicle.setConnectorType(input.getConnectorType());

        return vehicles.save(vehicle);
    }

    public void deleteVehicle(String sub, Long id) {
        requireRole(sub, "VEHICLE_OWNER");
        vehicles.delete(ownedVehicle(sub, id));
    }

    private Vehicle ownedVehicle(String sub, Long id) {
        Vehicle vehicle = vehicles.findById(id)
                .orElseThrow(() -> notFound("Vehicle"));

        if (!Objects.equals(
                vehicle.getOwnerUserId(),
                current(sub).getId()
        )) {
            throw forbidden();
        }

        return vehicle;
    }

    // --------------------------------------------------
    // CHARGING STATIONS
    // --------------------------------------------------

    public List<ChargingStation> browse() {
        return stations.findByActiveTrue();
    }

    public List<ChargingStation> mine(String sub) {
        return stations.findByOwnerUserId(current(sub).getId());
    }

    public ChargingStation station(Long id) {
        return stations.findById(id)
                .filter(ChargingStation::isActive)
                .orElseThrow(() -> notFound("Station"));
    }

    public ChargingStation saveStation(
            String sub,
            ChargingStation input
    ) {
        requireRole(sub, "CHARGER_PROVIDER");

        input.setOwnerUserId(current(sub).getId());
        validateStation(input);

        return stations.save(input);
    }

    public ChargingStation updateStation(
            String sub,
            Long id,
            ChargingStation input
    ) {
        ChargingStation existing = ownedStation(sub, id);

        input.setOwnerUserId(existing.getOwnerUserId());
        input.setActive(existing.isActive());

        validateStation(input);

        return copyStation(existing, input);
    }

    public ChargingStation setStationActive(
            String sub,
            Long id,
            boolean active
    ) {
        ChargingStation station = ownedStation(sub, id);
        station.setActive(active);

        return stations.save(station);
    }

    public void deactivateStation(String sub, Long id) {
        ChargingStation station = ownedStation(sub, id);
        station.setActive(false);

        stations.save(station);
    }

    private ChargingStation ownedStation(String sub, Long id) {
        ChargingStation station = stations.findById(id)
                .orElseThrow(() -> notFound("Station"));

        if (!Objects.equals(
                station.getOwnerUserId(),
                current(sub).getId()
        )) {
            throw forbidden();
        }

        return station;
    }

    private void requireRole(String sub, String required) {
        AppUser user = current(sub);

        if (user.getRole() == null) {
            throw new ResponseStatusException(
                    HttpStatus.FORBIDDEN,
                    "Assign a profile role (VEHICLE_OWNER or CHARGER_PROVIDER) before creating records"
            );
        }

        if (!required.equals(user.getRole())) {
            throw forbidden();
        }
    }

    private void validateStation(ChargingStation station) {
        validateCoordinates(station);

        if (station.getPowerKw() == null
                || station.getPowerKw().signum() <= 0) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "powerKw must be positive"
            );
        }

        if (station.getPricePerKwh() != null
                && station.getPricePerKwh().signum() < 0) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "pricePerKwh must be zero or greater"
            );
        }
    }

    private ChargingStation copyStation(
            ChargingStation station,
            ChargingStation input
    ) {
        station.setStationName(input.getStationName());
        station.setProviderType(input.getProviderType());
        station.setAccessType(input.getAccessType());
        station.setAddress(input.getAddress());
        station.setLatitude(input.getLatitude());
        station.setLongitude(input.getLongitude());
        station.setConnectorType(input.getConnectorType());
        station.setPowerKw(input.getPowerKw());
        station.setPricePerKwh(input.getPricePerKwh());

        return stations.save(station);
    }

    private void validateCoordinates(ChargingStation station) {
        if (station.getLatitude() == null
                || station.getLongitude() == null
                || station.getLatitude().doubleValue() < -90
                || station.getLatitude().doubleValue() > 90
                || station.getLongitude().doubleValue() < -180
                || station.getLongitude().doubleValue() > 180) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "Invalid coordinates"
            );
        }
    }

    public List<ChargingStation> nearby(
            double lat,
            double lon,
            double radius
    ) {
        if (lat < -90 || lat > 90
                || lon < -180 || lon > 180
                || radius <= 0 || radius > MAX_SEARCH_RADIUS_KM) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "Invalid coordinates or radius"
            );
        }

        return browse().stream()
                .filter(station -> distance(
                        lat, lon,
                        station.getLatitude().doubleValue(),
                        station.getLongitude().doubleValue()
                ) <= radius)
                .sorted(Comparator.comparingDouble(station -> distance(
                        lat, lon,
                        station.getLatitude().doubleValue(),
                        station.getLongitude().doubleValue()
                )))
                .toList();
    }

    private double distance(
            double lat1,
            double lon1,
            double lat2,
            double lon2
    ) {
        double x = Math.toRadians(lat2 - lat1);
        double y = Math.toRadians(lon2 - lon1);

        double h = Math.sin(x / 2) * Math.sin(x / 2)
                + Math.cos(Math.toRadians(lat1))
                * Math.cos(Math.toRadians(lat2))
                * Math.sin(y / 2) * Math.sin(y / 2);

        return 6371 * 2 * Math.atan2(
                Math.sqrt(h),
                Math.sqrt(1 - h)
        );
    }

    // --------------------------------------------------
    // CHARGER AVAILABILITY
    // --------------------------------------------------

    public List<ChargerAvailability> windows(Long id) {
        station(id);
        return availability.findByStationId(id);
    }

    public ChargerAvailability addWindow(
            String sub,
            Long id,
            ChargerAvailability window
    ) {
        ownedStation(sub, id);

        validTimes(window.getStartTime(), window.getEndTime());
        validateAvailabilityStatus(window.getStatus());
        window.setStationId(id);

        if (availability.existsByStationIdAndStartTimeLessThanAndEndTimeGreaterThan(
                id,
                window.getEndTime(),
                window.getStartTime()
        )) {
            throw conflict("Availability overlaps");
        }

        return availability.save(window);
    }

    public ChargerAvailability updateWindow(
            String sub,
            Long id,
            Long windowId,
            ChargerAvailability input
    ) {
        ownedStation(sub, id);

        ChargerAvailability old = availability.findById(windowId)
                .orElseThrow(() -> notFound("Availability"));

        if (!old.getStationId().equals(id)) {
            throw notFound("Availability");
        }

        validTimes(input.getStartTime(), input.getEndTime());
        validateAvailabilityStatus(input.getStatus());

        if (availability.existsByStationIdAndIdNotAndStartTimeLessThanAndEndTimeGreaterThan(
                id,
                windowId,
                input.getEndTime(),
                input.getStartTime()
        )) {
            throw conflict("Availability overlaps");
        }

        old.setStartTime(input.getStartTime());
        old.setEndTime(input.getEndTime());
        old.setStatus(input.getStatus());

        return availability.save(old);
    }

    public void deleteWindow(
            String sub,
            Long id,
            Long windowId
    ) {
        ownedStation(sub, id);

        availability.delete(
                availability.findById(windowId)
                        .filter(window -> window.getStationId().equals(id))
                        .orElseThrow(() -> notFound("Availability"))
        );
    }

    // --------------------------------------------------
    // BOOKINGS
    // --------------------------------------------------

    @Transactional
    public Booking createBooking(String sub, Booking booking) {
        requireRole(sub, "VEHICLE_OWNER");
        if (booking.getVehicleId() == null) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "vehicleId is required"
            );
        }

        if (booking.getStationId() == null) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "stationId is required"
            );
        }

        AppUser user = current(sub);

        Vehicle vehicle = ownedVehicle(sub, booking.getVehicleId());
        ChargingStation station = station(booking.getStationId());

        validTimes(booking.getStartTime(), booking.getEndTime());

        if (vehicle.getConnectorType() != null
                && !vehicle.getConnectorType().isBlank()
                && !vehicle.getConnectorType().equalsIgnoreCase(
                        station.getConnectorType()
                )) {
            throw conflict("Vehicle connector is incompatible with station");
        }

        // The availability window must contain the entire requested period.
        // Partial overlap is not sufficient.
        if (!availability
                .existsByStationIdAndStatusAndStartTimeLessThanEqualAndEndTimeGreaterThanEqual(
                        station.getId(),
                        "AVAILABLE",
                        booking.getStartTime(),
                        booking.getEndTime()
                )) {
            throw conflict(
                    "Requested time is not fully available"
            );
        }

        if (bookings.existsByStationIdAndStatusInAndStartTimeLessThanAndEndTimeGreaterThan(
                station.getId(),
                List.of("PENDING", "CONFIRMED"),
                booking.getEndTime(),
                booking.getStartTime()
        )) {
            throw conflict("Station is already booked");
        }

        booking.setSeekerUserId(user.getId());
        booking.setStatus("PENDING");
        booking.setEstimatedCost(
                estimateCost(
                        station,
                        booking.getStartTime(),
                        booking.getEndTime()
                )
        );

        return bookings.save(booking);
    }

    /**
     * Estimated cost:
     * price per kWh × rated station power × booked duration.
     *
     * This is an approximation. Actual cost is calculated
     * from measured energy when the session is completed.
     */
    private BigDecimal estimateCost(
            ChargingStation station,
            Instant start,
            Instant end
    ) {
        if (station.getPricePerKwh() == null
                || station.getPowerKw() == null
                || start == null
                || end == null) {
            return null;
        }

        long seconds = Duration.between(start, end).getSeconds();

        if (seconds <= 0) {
            return null;
        }

        BigDecimal hours = BigDecimal.valueOf(seconds)
                .divide(
                        BigDecimal.valueOf(3600),
                        6,
                        RoundingMode.HALF_UP
                );

        return station.getPricePerKwh()
                .multiply(station.getPowerKw())
                .multiply(hours)
                .setScale(2, RoundingMode.HALF_UP);
    }

    public List<Booking> bookings(String sub) {
        return bookings.findBySeekerUserId(current(sub).getId());
    }

    public Booking booking(String sub, Long id) {
        Booking booking = bookings.findById(id)
                .orElseThrow(() -> notFound("Booking"));

        AppUser user = current(sub);

        Long stationOwnerId = stations.findById(booking.getStationId())
                .map(ChargingStation::getOwnerUserId)
                .orElse(null);

        if (!Objects.equals(booking.getSeekerUserId(), user.getId())
                && !Objects.equals(stationOwnerId, user.getId())) {
            throw forbidden();
        }

        return booking;
    }

    /**
     * Only the vehicle owner may cancel their booking.
     * A booking cannot be cancelled after a charging session exists.
     */
    @Transactional
    public Booking cancelBooking(String sub, Long id) {
        Booking booking = booking(sub, id);

        if (!Objects.equals(
                booking.getSeekerUserId(),
                current(sub).getId()
        )) {
            throw forbidden();
        }

        if (!"PENDING".equals(booking.getStatus())
                && !"CONFIRMED".equals(booking.getStatus())) {
            throw conflict(
                    "Only pending or confirmed bookings can be cancelled"
            );
        }

        if (sessions.findByBookingId(id).isPresent()) {
            throw conflict(
                    "Booking cannot be cancelled after a charging session has started"
            );
        }

        booking.setStatus("CANCELLED");
        return bookings.save(booking);
    }

    /**
     * Only the station owner may confirm or reject a booking.
     */
    @Transactional
    public Booking decideBooking(
            String sub,
            Long id,
            String status
    ) {
        if (!"CONFIRMED".equals(status)
                && !"REJECTED".equals(status)) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "status must be CONFIRMED or REJECTED"
            );
        }

        Booking booking = booking(sub, id);

        ChargingStation station = stations.findById(booking.getStationId())
                .orElseThrow(() -> notFound("Station"));

        if (!Objects.equals(
                station.getOwnerUserId(),
                current(sub).getId()
        )) {
            throw forbidden();
        }

        if (!"PENDING".equals(booking.getStatus())) {
            throw conflict("Booking is not pending");
        }

        booking.setStatus(status);
        return bookings.save(booking);
    }

    public List<Booking> stationBookings(String sub, Long id) {
        ownedStation(sub, id);
        return bookings.findByStationId(id);
    }

    // --------------------------------------------------
    // CHARGING SESSIONS
    // --------------------------------------------------

    /**
     * Returns a booking only if the authenticated user is its station owner
     * and has the CHARGER_PROVIDER role.
     */
    private Booking providerBooking(String sub, Long bookingId) {
        requireRole(sub, "CHARGER_PROVIDER");

        Booking booking = bookings.findById(bookingId)
                .orElseThrow(() -> notFound("Booking"));

        ChargingStation station = stations.findById(booking.getStationId())
                .orElseThrow(() -> notFound("Station"));

        if (!Objects.equals(
                station.getOwnerUserId(),
                current(sub).getId()
        )) {
            throw forbidden();
        }

        return booking;
    }

    @Transactional
    public ChargingSession startSession(
            String sub,
            Long bookingId
    ) {
        Booking booking = bookings.findById(bookingId)
                .orElseThrow(() -> notFound("Booking"));

        AppUser actor = current(sub);

        boolean isSeeker = Objects.equals(
                booking.getSeekerUserId(),
                actor.getId()
        );

        if (!isSeeker) {
            requireRole(sub, "CHARGER_PROVIDER");

            ChargingStation station = stations.findById(booking.getStationId())
                    .orElseThrow(() -> notFound("Station"));

            if (!Objects.equals(
                    station.getOwnerUserId(),
                    actor.getId()
            )) {
                throw forbidden();
            }
        }

        if (!"CONFIRMED".equals(booking.getStatus())) {
            throw conflict("Booking must be confirmed");
        }

        if (sessions.findByBookingId(bookingId).isPresent()) {
            throw conflict("Session already exists");
        }

        ChargingSession session = new ChargingSession();
        session.setBookingId(bookingId);
        session.setActualStartTime(Instant.now());

        try {
            return sessions.saveAndFlush(session);
        } catch (DataIntegrityViolationException exception) {
            throw conflict(
                    "A charging session already exists for this booking"
            );
        }
    }

    /**
     * Session details can be viewed by either the vehicle owner
     * or the station owner.
     */
    public ChargingSession session(String sub, Long id) {
        ChargingSession session = sessions.findById(id)
                .orElseThrow(() -> notFound("Session"));

        booking(sub, session.getBookingId());

        return session;
    }

    public ChargingSession sessionByBooking(
            String sub,
            Long bookingId
    ) {
        booking(sub, bookingId);

        return sessions.findByBookingId(bookingId)
                .orElseThrow(() -> notFound("Session"));
    }

    @Transactional
    public ChargingSession completeSession(
            String sub,
            Long id,
            ChargingSession input
    ) {
        ChargingSession session = sessions.findById(id)
                .orElseThrow(() -> notFound("Session"));

        // Completion is restricted to the station owner.
        Booking booking = providerBooking(sub, session.getBookingId());

        if (!"IN_PROGRESS".equals(session.getStatus())) {
            throw conflict("Session is not active");
        }

        BigDecimal energy = input.getEnergyConsumedKwh();

        if (energy == null || energy.signum() <= 0) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "energyConsumedKwh must be greater than zero"
            );
        }

        ChargingStation station = stations.findById(booking.getStationId())
                .orElseThrow(() -> notFound("Station"));

        BigDecimal pricePerKwh = station.getPricePerKwh();

        if (pricePerKwh == null || pricePerKwh.signum() < 0) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "Station price is invalid"
            );
        }

        // Actual bill = measured energy × station price per kWh.
        BigDecimal finalCost = energy
                .multiply(pricePerKwh)
                .setScale(2, RoundingMode.HALF_UP);

        session.setEnergyConsumedKwh(energy);
        session.setFinalCost(finalCost);
        session.setActualEndTime(Instant.now());
        session.setStatus("COMPLETED");

        return sessions.save(session);
    }

    public List<ChargingSession> mySessions(String sub) {
        return bookings(sub).stream()
                .map(Booking::getId)
                .flatMap(id -> sessions.findByBookingId(id).stream())
                .toList();
    }

    // --------------------------------------------------
    // STATION IMAGES
    // --------------------------------------------------

    public List<StationImage> images(Long id) {
        station(id);
        return images.findByStationId(id);
    }

    public StationImage addImage(
            String sub,
            Long id,
            StationImage input
    ) {
        ownedStation(sub, id);

        if (input.getS3ObjectKey() == null
                || input.getS3ObjectKey().isBlank()) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "s3ObjectKey is required"
            );
        }

        input.setStationId(id);
        return images.save(input);
    }

    public void deleteImage(
            String sub,
            Long id,
            Long imageId
    ) {
        ownedStation(sub, id);

        images.delete(
                images.findById(imageId)
                        .filter(image -> image.getStationId().equals(id))
                        .orElseThrow(() -> notFound("Image"))
        );
    }

    // --------------------------------------------------
    // COMMON VALIDATION AND ERRORS
    // --------------------------------------------------

    private void validTimes(Instant start, Instant end) {
        if (start == null || end == null || !end.isAfter(start)) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "endTime must be after startTime"
            );
        }
    }

    private void validateAvailabilityStatus(String status) {
        if (status == null || status.isBlank()) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "status is required"
            );
        }

        if (!"AVAILABLE".equals(status)) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "status must be AVAILABLE"
            );
        }
    }

    private String required(String value, String name) {
        if (value == null || value.isBlank()) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    name + " is required"
            );
        }

        return value;
    }

    private ResponseStatusException notFound(String name) {
        return new ResponseStatusException(
                HttpStatus.NOT_FOUND,
                name + " not found"
        );
    }

    private ResponseStatusException forbidden() {
        return new ResponseStatusException(
                HttpStatus.FORBIDDEN,
                "Not authorized"
        );
    }

    private ResponseStatusException conflict(String message) {
        return new ResponseStatusException(
                HttpStatus.CONFLICT,
                message
        );
    }
}
