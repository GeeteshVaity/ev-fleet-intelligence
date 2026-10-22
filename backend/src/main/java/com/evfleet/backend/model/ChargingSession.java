package com.evfleet.backend.model;
import jakarta.persistence.*; import java.math.BigDecimal; import java.time.Instant;
@Entity @Table(name="charging_sessions",uniqueConstraints=@UniqueConstraint(name="uk_session_booking",columnNames="booking_id"))
public class ChargingSession {
 @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id; @Column(nullable=false) private Long bookingId; private Instant actualStartTime; private Instant actualEndTime; private BigDecimal energyConsumedKwh; private BigDecimal finalCost; @Column(nullable=false,length=20) private String status="IN_PROGRESS";
 public ChargingSession(){} public Long getId(){return id;} public Long getBookingId(){return bookingId;} public void setBookingId(Long v){bookingId=v;} public Instant getActualStartTime(){return actualStartTime;} public void setActualStartTime(Instant v){actualStartTime=v;} public Instant getActualEndTime(){return actualEndTime;} public void setActualEndTime(Instant v){actualEndTime=v;} public BigDecimal getEnergyConsumedKwh(){return energyConsumedKwh;} public void setEnergyConsumedKwh(BigDecimal v){energyConsumedKwh=v;} public BigDecimal getFinalCost(){return finalCost;} public void setFinalCost(BigDecimal v){finalCost=v;} public String getStatus(){return status;} public void setStatus(String v){status=v;}
}
