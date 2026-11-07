ALTER TABLE vehicles
    ADD CONSTRAINT fk_vehicles_owner
        FOREIGN KEY (owner_user_id) REFERENCES users(id);

ALTER TABLE charging_stations
    ADD CONSTRAINT fk_stations_owner
        FOREIGN KEY (owner_user_id) REFERENCES users(id);

ALTER TABLE charger_availability
    ADD CONSTRAINT fk_availability_station
        FOREIGN KEY (station_id) REFERENCES charging_stations(id) ON DELETE CASCADE;

ALTER TABLE charger_availability
    ADD CONSTRAINT ck_availability_time
        CHECK (end_time > start_time);

ALTER TABLE charger_availability
    ADD CONSTRAINT ck_availability_status
        CHECK (status = 'AVAILABLE');

ALTER TABLE bookings
    ADD CONSTRAINT fk_bookings_seeker
        FOREIGN KEY (seeker_user_id) REFERENCES users(id);

ALTER TABLE bookings
    ADD CONSTRAINT fk_bookings_vehicle
        FOREIGN KEY (vehicle_id) REFERENCES vehicles(id);

ALTER TABLE bookings
    ADD CONSTRAINT fk_bookings_station
        FOREIGN KEY (station_id) REFERENCES charging_stations(id);

ALTER TABLE bookings
    ADD CONSTRAINT ck_bookings_time
        CHECK (end_time > start_time);

ALTER TABLE bookings
    ADD CONSTRAINT ck_bookings_status
        CHECK (status IN ('PENDING', 'CONFIRMED', 'REJECTED', 'CANCELLED'));

ALTER TABLE charging_sessions
    ADD CONSTRAINT fk_sessions_booking
        FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE;

ALTER TABLE charging_sessions
    ADD CONSTRAINT ck_sessions_status
        CHECK (status IN ('IN_PROGRESS', 'COMPLETED'));

ALTER TABLE station_images
    ADD CONSTRAINT fk_images_station
        FOREIGN KEY (station_id) REFERENCES charging_stations(id) ON DELETE CASCADE;

ALTER TABLE charging_stations
    ADD CONSTRAINT ck_station_coordinates
        CHECK (latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180);

ALTER TABLE charging_stations
    ADD CONSTRAINT ck_station_power
        CHECK (power_kw > 0);

ALTER TABLE charging_stations
    ADD CONSTRAINT ck_station_price
        CHECK (price_per_kwh IS NULL OR price_per_kwh >= 0);

ALTER TABLE vehicles
    ADD CONSTRAINT ck_vehicle_battery
        CHECK (battery_capacity_kwh IS NULL OR battery_capacity_kwh > 0);