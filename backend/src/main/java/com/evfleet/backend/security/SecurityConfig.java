package com.evfleet.backend.security;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.oauth2.jwt.JwtDecoders;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
@EnableWebSecurity
public class SecurityConfig {
    @Value("${app.cognito.issuer-uri}")
    private String issuerUri;

    @Bean
    @Order(1)
    @ConditionalOnProperty(name = "app.cognito.enabled", havingValue = "true")
    SecurityFilterChain cognitoSecurity(HttpSecurity http) throws Exception {
        var converter = new JwtAuthenticationConverter();
        converter.setPrincipalClaimName("sub");
        http
            .csrf(csrf -> csrf.disable())
            .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/actuator/health", "/error").permitAll()
                .anyRequest().authenticated())
            .oauth2ResourceServer(oauth -> oauth
                .jwt(jwt -> jwt
                    .decoder(JwtDecoders.fromIssuerLocation(issuerUri))
                    .jwtAuthenticationConverter(converter)));
        return http.build();
    }

    @Bean
    @Order(2)
    @ConditionalOnProperty(name = "app.cognito.enabled", havingValue = "false", matchIfMissing = true)
    SecurityFilterChain unconfiguredSecurity(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf.disable())
            .authorizeHttpRequests(auth -> auth.anyRequest().denyAll());
        return http.build();
    }
}
