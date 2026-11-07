package com.evfleet.backend.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springdoc.core.customizers.OpenApiCustomizer;

@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI customOpenAPI() {
        return new OpenAPI()
                .addSecurityItem(new SecurityRequirement().addList("bearerAuth"))
                .schemaRequirement(
                        "bearerAuth",
                        new SecurityScheme()
                                .type(SecurityScheme.Type.HTTP)
                                .scheme("bearer")
                                .bearerFormat("JWT")
                );
    }

    @Bean
    public OpenApiCustomizer publicEndpointsCustomizer() {
        return openApi -> {
            if (openApi.getPaths() == null) return;

            String[][] publicEndpoints = {
                    {"GET", "/api/stations"},
                    {"GET", "/api/stations/nearby"},
                    {"GET", "/api/stations/{id}"},
                    {"GET", "/api/stations/{id}/availability"}
            };

            for (String[] endpoint : publicEndpoints) {
                var pathItem = openApi.getPaths().get(endpoint[1]);

                if (pathItem != null) {
                    var operation = pathItem.readOperationsMap()
                            .get(io.swagger.v3.oas.models.PathItem.HttpMethod.valueOf(endpoint[0]));

                    if (operation != null) {
                        operation.setSecurity(java.util.Collections.emptyList());
                    }
                }
            }
        };
    }
}