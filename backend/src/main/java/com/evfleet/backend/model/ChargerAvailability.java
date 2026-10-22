package com.evfleet.backend.model;
import jakarta.persistence.*; import java.time.Instant;
@Entity @Table(name="charger_availability")
public class ChargerAvailability {
 @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id; @Column(nullable=false) private Long stationId; @Column(nullable=false) private Instant startTime; @Column(nullable=false) private Instant endTime; @Column(nullable=false,length=20) private String status="AVAILABLE";
 public ChargerAvailability(){} public Long getId(){return id;} public Long getStationId(){return stationId;} public void setStationId(Long v){stationId=v;} public Instant getStartTime(){return startTime;} public void setStartTime(Instant v){startTime=v;} public Instant getEndTime(){return endTime;} public void setEndTime(Instant v){endTime=v;} public String getStatus(){return status;} public void setStatus(String v){status=v;}
}
