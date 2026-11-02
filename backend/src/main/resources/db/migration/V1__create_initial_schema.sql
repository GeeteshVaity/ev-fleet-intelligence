CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    cognito_sub VARCHAR(128) NOT NULL,
    full_name VARCHAR(120) NOT NULL,
    email VARCHAR(254) NOT NULL,
    phone VARCHAR(30),
    role VARCHAR(30),
    onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE,
    onboarding_step INTEGER,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT uk_users_sub UNIQUE (cognito_sub),
    CONSTRAINT uk_users_email UNIQUE (email)
);

CREATE TABLE vehicles (
    id BIGSERIAL PRIMARY KEY,
    owner_user_id BIGINT NOT NULL,
    vehicle_type VARCHAR(20) NOT NULL,
    brand VARCHAR(80),
    model VARCHAR(80) NOT NULL,
    registration_number VARCHAR(30),
    battery_capacity_kwh NUMERIC(7,2),
    connector_type VARCHAR(40),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE INDEX idx_vehicles_owner ON vehicles(owner_user_id);

CREATE TABLE charging_stations (
    id BIGSERIAL PRIMARY KEY,
    owner_user_id BIGINT,
    station_name VARCHAR(140) NOT NULL,
    provider_type VARCHAR(20) NOT NULL,
    access_type VARCHAR(20) NOT NULL,
    address VARCHAR(255) NOT NULL,
    latitude NUMERIC(9,6) NOT NULL,
    longitude NUMERIC(9,6) NOT NULL,
    connector_type VARCHAR(40) NOT NULL,
    power_kw NUMERIC(7,2) NOT NULL,
    price_per_kwh NUMERIC(8,2),
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE INDEX idx_stations_owner ON charging_stations(owner_user_id);

CREATE TABLE charger_availability (
    id BIGSERIAL PRIMARY KEY,
    station_id BIGINT NOT NULL,
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'AVAILABLE'
);

CREATE TABLE bookings (
    id BIGSERIAL PRIMARY KEY,
    seeker_user_id BIGINT NOT NULL,
    vehicle_id BIGINT NOT NULL,
    station_id BIGINT NOT NULL,
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    estimated_cost NUMERIC(19,2),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE INDEX idx_bookings_station_time ON bookings(station_id, start_time, end_time);

CREATE TABLE charging_sessions (
    id BIGSERIAL PRIMARY KEY,
    booking_id BIGINT NOT NULL,
    actual_start_time TIMESTAMP WITH TIME ZONE,
    actual_end_time TIMESTAMP WITH TIME ZONE,
    energy_consumed_kwh NUMERIC(19,2),
    final_cost NUMERIC(19,2),
    status VARCHAR(20) NOT NULL DEFAULT 'IN_PROGRESS',
    CONSTRAINT uk_session_booking UNIQUE (booking_id)
);

CREATE TABLE station_images (
    id BIGSERIAL PRIMARY KEY,
    station_id BIGINT NOT NULL,
    s3_object_key VARCHAR(512) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT uk_image_key UNIQUE (s3_object_key)
);
