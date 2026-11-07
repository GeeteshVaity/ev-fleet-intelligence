package com.evfleet.backend.security;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtDecoders;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.List;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Value("${app.cognito.issuer-uri:}")
    private String issuerUri;

    @Value("${app.cognito.client-id:}")
    private String clientId;

    @Value("${app.frontend.origin:http://localhost:3000}")
    private String frontendOrigin;

    // ------------------------------------------------------------------
    // Cognito JWT security chain
    // ------------------------------------------------------------------

    @Bean
    @Order(1)
    @ConditionalOnProperty(
            name = "app.cognito.enabled",
            havingValue = "true"
    )
    SecurityFilterChain cognitoSecurity(HttpSecurity http) throws Exception {

        http
                .cors(cors -> cors.configurationSource(corsConfigurationSource()))
                .csrf(csrf -> csrf.disable())
                .sessionManagement(session ->
                        session.sessionCreationPolicy(SessionCreationPolicy.STATELESS)
                )
                .authorizeHttpRequests(auth -> auth

                        // CORS preflight
                        .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()

                        // Health and error endpoints
                        .requestMatchers(
                                "/actuator/health",
                                "/error"
                        ).permitAll()

                        // Swagger / OpenAPI documentation
                        .requestMatchers(
                                "/v3/api-docs/**",
                                "/v3/api-docs.yaml",
                                "/swagger-ui/**",
                                "/swagger-ui.html"
                        ).permitAll()

                        // Provider-owned station listings require authentication
                        .requestMatchers(
                                HttpMethod.GET,
                                "/api/stations/mine"
                        ).authenticated()

                        // Public station discovery
                        .requestMatchers(
                                HttpMethod.GET,
                                "/api/stations",
                                "/api/stations/nearby",
                                "/api/stations/{id}",
                                "/api/stations/{id}/availability"
                        ).permitAll()

                        // All remaining endpoints require Cognito authentication
                        .anyRequest().authenticated()
                )
                .oauth2ResourceServer(oauth -> oauth
                        .jwt(jwt -> jwt
                                .decoder(jwtDecoder())
                                .jwtAuthenticationConverter(jwtAuthenticationConverter())
                        )
                );

        return http.build();
    }

    // ------------------------------------------------------------------
    // Development deny-by-default security chain
    // ------------------------------------------------------------------

    @Bean
    @Order(2)
    @ConditionalOnProperty(
            name = "app.cognito.enabled",
            havingValue = "false",
            matchIfMissing = true
    )
    SecurityFilterChain unconfiguredSecurity(HttpSecurity http) throws Exception {

        http
                .cors(cors -> cors.configurationSource(corsConfigurationSource()))
                .csrf(csrf -> csrf.disable())
                .authorizeHttpRequests(auth -> auth

                        .requestMatchers(
                                HttpMethod.OPTIONS,
                                "/**"
                        ).permitAll()

                        .requestMatchers(
                                "/actuator/health",
                                "/error"
                        ).permitAll()

                        // Allow documentation, not business API access
                        .requestMatchers(
                                "/v3/api-docs/**",
                                "/v3/api-docs.yaml",
                                "/swagger-ui/**",
                                "/swagger-ui.html"
                        ).permitAll()

                        // Everything else remains denied
                        .anyRequest().denyAll()
                );

        return http.build();
    }

    // ------------------------------------------------------------------
    // Cognito JWT decoder
    // ------------------------------------------------------------------

    @Bean
    @ConditionalOnProperty(
            name = "app.cognito.enabled",
            havingValue = "true"
    )
    JwtDecoder jwtDecoder() {

        if (issuerUri == null || issuerUri.isBlank()) {
            throw new IllegalStateException(
                    "COGNITO_ISSUER_URI must be configured"
            );
        }

        if (clientId == null || clientId.isBlank()) {
            throw new IllegalStateException(
                    "COGNITO_CLIENT_ID must be configured"
            );
        }

        NimbusJwtDecoder decoder =
                (NimbusJwtDecoder) JwtDecoders.fromIssuerLocation(issuerUri);

        decoder.setJwtValidator(
                new DelegatingOAuth2TokenValidator<>(
                        JwtValidators.createDefaultWithIssuer(issuerUri),
                        accessTokenValidator()
                )
        );

        return decoder;
    }

    // ------------------------------------------------------------------
    // Cognito access-token validation
    // ------------------------------------------------------------------

    OAuth2TokenValidator<Jwt> accessTokenValidator() {

        return jwt -> {

            String tokenUse = jwt.getClaimAsString("token_use");
            String tokenClientId = jwt.getClaimAsString("client_id");

            if (!"access".equals(tokenUse)) {
                return OAuth2TokenValidatorResult.failure(
                        new OAuth2Error(
                                "invalid_token",
                                "Cognito access token required",
                                null
                        )
                );
            }

            if (!clientId.equals(tokenClientId)) {
                return OAuth2TokenValidatorResult.failure(
                        new OAuth2Error(
                                "invalid_token",
                                "Token was not issued for the configured app client",
                                null
                        )
                );
            }

            return OAuth2TokenValidatorResult.success();
        };
    }

    // ------------------------------------------------------------------
    // JWT authentication converter
    // ------------------------------------------------------------------

    JwtAuthenticationConverter jwtAuthenticationConverter() {

        JwtAuthenticationConverter converter =
                new JwtAuthenticationConverter();

        converter.setPrincipalClaimName("sub");

        return converter;
    }

    // ------------------------------------------------------------------
    // CORS configuration
    // ------------------------------------------------------------------

    @Bean
    CorsConfigurationSource corsConfigurationSource() {

        CorsConfiguration config = new CorsConfiguration();

        config.setAllowedOrigins(List.of(frontendOrigin));

        config.setAllowedMethods(List.of(
                HttpMethod.GET.name(),
                HttpMethod.POST.name(),
                HttpMethod.PUT.name(),
                HttpMethod.PATCH.name(),
                HttpMethod.DELETE.name(),
                HttpMethod.OPTIONS.name()
        ));

        config.setAllowedHeaders(List.of(
                HttpHeaders.AUTHORIZATION,
                HttpHeaders.CONTENT_TYPE,
                HttpHeaders.ACCEPT,
                "X-Requested-With"
        ));

        config.setExposedHeaders(List.of(
                HttpHeaders.AUTHORIZATION
        ));

        config.setAllowCredentials(true);
        config.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource source =
                new UrlBasedCorsConfigurationSource();

        source.registerCorsConfiguration("/**", config);

        return source;
    }
}