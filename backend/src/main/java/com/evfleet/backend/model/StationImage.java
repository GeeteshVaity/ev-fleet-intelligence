package com.evfleet.backend.model;
import jakarta.persistence.*; import java.time.Instant;
@Entity @Table(name="station_images",uniqueConstraints=@UniqueConstraint(name="uk_image_key",columnNames="s3_object_key"))
public class StationImage {
 @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id; @Column(nullable=false) private Long stationId; @Column(name="s3_object_key",nullable=false,length=512) private String s3ObjectKey; private Instant createdAt=Instant.now();
 public StationImage(){} public Long getId(){return id;} public Long getStationId(){return stationId;} public void setStationId(Long v){stationId=v;} public String getS3ObjectKey(){return s3ObjectKey;} public void setS3ObjectKey(String v){s3ObjectKey=v;} public Instant getCreatedAt(){return createdAt;}
}
