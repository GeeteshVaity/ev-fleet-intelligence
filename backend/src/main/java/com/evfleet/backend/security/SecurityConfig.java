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

/**
 * Spring Security configuration.
 *
 * <h2>Two modes</h2>
 * <ul>
 * <li><b>Cognito mode</b> ({@code COGNITO_ENABLED=true}): validates every
 * request against Cognito access-token JWTs. All {@code /api/**} routes
 * require a valid Bearer token except the CORS preflight and the health
 * check. Production must run in this mode.</li>
 * <li><b>Dev-deny mode</b> (default / {@code COGNITO_ENABLED=false}): all
 * requests are denied so the server fails safely when Cognito is not yet
 * configured. Use the documented local-dev profile only for unit tests
 * (see {@code application-test.properties}).</li>
 * </ul>
 *
 * <h2>JWT validation</h2>
 * <ul>
 * <li>Signatures are verified against Cognito's published JWKS.</li>
 * <li>Issuer and expiry claims are validated by the standard Spring
 * Security decoder pipeline.</li>
 * <li>Access tokens carry {@code token_use: access}; ID tokens are
 * not accepted as API credentials.</li>
 * <li>The principal name is set to the {@code sub} claim (stable UUID).</li>
 * </ul>
 *
 * <h2>CORS</h2>
 * Set {@code FRONTEND_ORIGIN} to the exact allowed origin of your Flutter web
 * or web-app clients. Wildcard ({@code *}) origins with credentials are never
 * used.
 */
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Value("${app.cognito.issuer-uri:}")
    private String issuerUri;

    @Value("${app.frontend.origin:http://localhost:3000}")
    private String frontendOrigin;

    // ---------------------------------------------------------------------------
    // Cognito JWT security chain (production)
    // ---------------------------------------------------------------------------

    @Bean
    @Order(1)
    @ConditionalOnProperty(name = "app.cognito.enabled", havingValue = "true")
    SecurityFilterChain cognitoSecurity(HttpSecurity http) throws Exception {
        http
                .cors(cors -> cors.configurationSource(corsConfigurationSource()))
                .csrf(csrf -> csrf.disable())
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        // CORS preflight must be open
                        .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                        // Health check and error mapping
                        .requestMatchers("/actuator/health", "/error").permitAll()
                        // Stations list and nearby are intentionally public (discovery experience)
                        .requestMatchers(HttpMethod.GET, "/api/stations", "/api/stations/nearby",
                                "/api/stations/{id}", "/api/stations/{id}/availability")
                        .permitAll()
                        // Everything else requires a valid Cognito access token
                        .anyRequest().authenticated())
                .oauth2ResourceServer(oauth -> oauth
                        .jwt(jwt -> jwt
                                .decoder(jwtDecoder())
                                .jwtAuthenticationConverter(jwtAuthenticationConverter())));
        return http.build();
    }

    // ---------------------------------------------------------------------------
    // Dev-deny chain (default / Cognito not configured)
    // ---------------------------------------------------------------------------

    /**
     * When Cognito is not enabled the server denies all requests so that it
     * fails safely in production rather than silently skipping authentication.
     *
     * <p>
     * Unit tests activate the {@code test} Spring profile which sets
     * {@code app.cognito.enabled=false} and relies on standalone MockMvc
     * or a separately wired security context.
     */
    @Bean
    @Order(2)
    @ConditionalOnProperty(name = "app.cognito.enabled", havingValue = "false", matchIfMissing = true)
    SecurityFilterChain unconfiguredSecurity(HttpSecurity http) throws Exception {
        http
                .cors(cors -> cors.configurationSource(corsConfigurationSource()))
                .csrf(csrf -> csrf.disable())
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                        .requestMatchers("/actuator/health", "/error").permitAll()
                        .anyRequest().denyAll());
        return http.build();
    }

    // ---------------------------------------------------------------------------
    // JWT decoder
    // ---------------------------------------------------------------------------

    /**
     * Builds a {@link JwtDecoder} backed by Cognito's JWKS endpoint.
     *
     * <p>
     * Standard Spring Security validation pipeline checks:
     * <ul>
     * <li>Signature (RSA, verified against the JWKS published by Cognito)</li>
     * <li>Issuer ({@code iss} must match {@code COGNITO_ISSUER_URI})</li>
     * <li>Expiry ({@code exp} must be in the future)</li>
     * <li>Not-before ({@code nbf} when present)</li>
     * </ul>
     *
     * <p>
     * Cognito access tokens do NOT always include an {@code aud} claim when
     * machine-to-machine scopes are absent; prefer validating {@code client_id}
     * via a custom validator or at the application layer if audience enforcement
     * is required.
     *
     * <p>
     * Called only when {@code app.cognito.enabled=true} so an empty/missing
     * issuer URI in dev/test mode never causes a startup failure.
     */
    @Bean
    @ConditionalOnProperty(name = "app.cognito.enabled", havingValue = "true")
    JwtDecoder jwtDecoder() {
        if (issuerUri == null || issuerUri.isBlank()) {
            throw new IllegalStateException(
                    "COGNITO_ISSUER_URI must be set when app.cognito.enabled=true. " +
                            "Format: https://cognito-idp.<region>.amazonaws.com/<user-pool-id>");
        }
        NimbusJwtDecoder decoder = (NimbusJwtDecoder) JwtDecoders.fromIssuerLocation(issuerUri);
        // Explicitly set the issuer validator to surface clear errors on
        // misconfiguration
        decoder.setJwtValidator(new DelegatingOAuth2TokenValidator<>(
                JwtValidators.createDefaultWithIssuer(issuerUri),
                accessTokenValidator()));
        return decoder;
    }

    /**
     * Cognito signs access and ID tokens with the same keys, so token_use must
     * be checked in addition to signature, issuer, and time validation.
     */
    OAuth2TokenValidator<Jwt> accessTokenValidator() {
        return jwt -> "access".equals(jwt.getClaimAsString("token_use"))
                ? OAuth2TokenValidatorResult.success()
                : OAuth2TokenValidatorResult.failure(new OAuth2Error(
                        "invalid_token", "Cognito access token required", null));
    }

    // ---------------------------------------------------------------------------
    // JWT authentication converter (maps sub → principal name)
    // ---------------------------------------------------------------------------

    JwtAuthenticationConverter jwtAuthenticationConverter() {
        JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
        // Use the stable Cognito subject UUID as the principal name.
        // Never use email or username — they can change.
        converter.setPrincipalClaimName("sub");
        return converter;
    }

    // ---------------------------------------------------------------------------
    // CORS
    // ---------------------------------------------------------------------------

    /**
     * Configures CORS to allow only the explicitly provided frontend origin.
     *
     * <p>
     * Wildcard origins with credentials are prohibited by the CORS specification
     * and are never used here. Set {@code FRONTEND_ORIGIN} in production.
     */
    @Bean
    CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOrigins(List.of(frontendOrigin));
        config.setAllowedMethods(List.of(
                HttpMethod.GET.name(), HttpMethod.POST.name(), HttpMethod.PUT.name(),
                HttpMethod.PATCH.name(), HttpMethod.DELETE.name(), HttpMethod.OPTIONS.name()));
        config.setAllowedHeaders(List.of(
                HttpHeaders.AUTHORIZATION,
                HttpHeaders.CONTENT_TYPE,
                HttpHeaders.ACCEPT,
                "X-Requested-With"));
        config.setExposedHeaders(List.of(HttpHeaders.AUTHORIZATION));
        config.setAllowCredentials(true);
        config.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }
}
