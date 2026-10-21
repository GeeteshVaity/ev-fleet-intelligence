package com.evfleet.backend.model;



import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "vehicles")
public class Vehicle {

    @Id
    private String vehicleId;

    private String vehicleType;

    private int batterySoc;

    private double speedKmph;

    private String chargingStatus;

    public Vehicle() {
    }

    public Vehicle(String vehicleId, String vehicleType,
                   int batterySoc, double speedKmph,
                   String chargingStatus) {
        this.vehicleId = vehicleId;
        this.vehicleType = vehicleType;
        this.batterySoc = batterySoc;
        this.speedKmph = speedKmph;
        this.chargingStatus = chargingStatus;
    }

    public String getVehicleId() {
        return vehicleId;
    }

    public void setVehicleId(String vehicleId) {
        this.vehicleId = vehicleId;
    }

    public String getVehicleType() {
        return vehicleType;
    }

    public void setVehicleType(String vehicleType) {
        this.vehicleType = vehicleType;
    }

    public int getBatterySoc() {
        return batterySoc;
    }

    public void setBatterySoc(int batterySoc) {
        this.batterySoc = batterySoc;
    }

    public double getSpeedKmph() {
        return speedKmph;
    }

    public void setSpeedKmph(double speedKmph) {
        this.speedKmph = speedKmph;
    }

    public String getChargingStatus() {
        return chargingStatus;
    }

    public void setChargingStatus(String chargingStatus) {
        this.chargingStatus = chargingStatus;
    }
}

