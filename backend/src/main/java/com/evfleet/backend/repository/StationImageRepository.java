package com.evfleet.backend.repository;
import com.evfleet.backend.model.StationImage;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
public interface StationImageRepository extends JpaRepository<StationImage, Long> { List<StationImage> findByStationId(Long stationId); }
