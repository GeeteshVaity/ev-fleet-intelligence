package com.evfleet.backend.security;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.web.server.ResponseStatusException;

public final class CurrentUser {
    private CurrentUser() {}

    public static String subject(Authentication authentication) {
        if (authentication instanceof JwtAuthenticationToken jwt && jwt.getToken().getSubject() != null) {
            return jwt.getToken().getSubject();
        }
        throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "A Cognito access token is required");
    }
}
