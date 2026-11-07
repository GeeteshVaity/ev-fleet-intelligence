package com.evfleet.backend.security;

import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.Instant;

import static org.assertj.core.api.Assertions.assertThat;

class SecurityConfigTest {

    @Test
    void acceptsAccessTokenFromConfiguredClient() {
        SecurityConfig config = config("configured-client");

        OAuth2TokenValidatorResult result = config.accessTokenValidator().validate(
                token("access", "configured-client")
        );

        assertThat(result.hasErrors()).isFalse();
    }

    @Test
    void rejectsAccessTokenFromAnotherClient() {
        SecurityConfig config = config("configured-client");

        OAuth2TokenValidatorResult result = config.accessTokenValidator().validate(
                token("access", "different-client")
        );

        assertThat(result.hasErrors()).isTrue();
    }

    @Test
    void rejectsIdTokenEvenWhenClientMatches() {
        SecurityConfig config = config("configured-client");

        OAuth2TokenValidatorResult result = config.accessTokenValidator().validate(
                token("id", "configured-client")
        );

        assertThat(result.hasErrors()).isTrue();
    }

    private SecurityConfig config(String clientId) {
        SecurityConfig config = new SecurityConfig();
        ReflectionTestUtils.setField(config, "clientId", clientId);
        return config;
    }

    private Jwt token(String tokenUse, String clientId) {
        return Jwt.withTokenValue("token")
                .header("alg", "RS256")
                .claim("token_use", tokenUse)
                .claim("client_id", clientId)
                .issuedAt(Instant.now().minusSeconds(10))
                .expiresAt(Instant.now().plusSeconds(300))
                .build();
    }
}
