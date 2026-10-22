package com.evfleet.backend.model;
import jakarta.persistence.*; import java.time.Instant;
import jakarta.validation.constraints.*;
@Entity @Table(name="users", uniqueConstraints={@UniqueConstraint(name="uk_users_sub",columnNames="cognito_sub"),@UniqueConstraint(name="uk_users_email",columnNames="email")})
public class AppUser {
 @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id; @Column(name="cognito_sub",nullable=false,length=128) private String cognitoSub; @NotBlank @Size(max=120) @Column(nullable=false,length=120) private String fullName; @NotBlank @Email @Size(max=254) @Column(nullable=false,length=254) private String email; @Size(max=30) @Column(length=30) private String phone; private Instant createdAt=Instant.now(); private Instant updatedAt=Instant.now();
 public AppUser(){} public Long getId(){return id;} public String getCognitoSub(){return cognitoSub;} public void setCognitoSub(String v){cognitoSub=v;} public String getFullName(){return fullName;} public void setFullName(String v){fullName=v;} public String getEmail(){return email;} public void setEmail(String v){email=v;} public String getPhone(){return phone;} public void setPhone(String v){phone=v;} public Instant getCreatedAt(){return createdAt;} public Instant getUpdatedAt(){return updatedAt;} public void touch(){updatedAt=Instant.now();}
}
