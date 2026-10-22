package com.evfleet.backend.model;
import jakarta.persistence.*; import java.math.BigDecimal; import java.time.Instant;
import jakarta.validation.constraints.*;
@Entity @Table(name="bookings",indexes=@Index(name="idx_bookings_station_time",columnList="station_id,start_time,end_time"))
public class Booking {
 @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id; @Column(nullable=false) private Long seekerUserId; @NotNull @Column(nullable=false) private Long vehicleId; @NotNull @Column(nullable=false) private Long stationId; @NotNull @Column(nullable=false) private Instant startTime; @NotNull @Column(nullable=false) private Instant endTime; @Column(nullable=false,length=20) private String status="PENDING"; private BigDecimal estimatedCost; private Instant createdAt=Instant.now();
 public Booking(){} public Long getId(){return id;} public Long getSeekerUserId(){return seekerUserId;} public void setSeekerUserId(Long v){seekerUserId=v;} public Long getVehicleId(){return vehicleId;} public void setVehicleId(Long v){vehicleId=v;} public Long getStationId(){return stationId;} public void setStationId(Long v){stationId=v;} public Instant getStartTime(){return startTime;} public void setStartTime(Instant v){startTime=v;} public Instant getEndTime(){return endTime;} public void setEndTime(Instant v){endTime=v;} public String getStatus(){return status;} public void setStatus(String v){status=v;} public BigDecimal getEstimatedCost(){return estimatedCost;} public void setEstimatedCost(BigDecimal v){estimatedCost=v;}
}
