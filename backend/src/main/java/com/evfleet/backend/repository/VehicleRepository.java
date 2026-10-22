package com.evfleet.backend.repository;



import com.evfleet.backend.model.Vehicle;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
public interface VehicleRepository extends JpaRepository<Vehicle, Long> { List<Vehicle> findByOwnerUserId(Long ownerUserId); }
