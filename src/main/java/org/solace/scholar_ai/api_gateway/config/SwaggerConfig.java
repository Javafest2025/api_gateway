package org.solace.scholar_ai.api_gateway.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.License;
import org.springdoc.core.properties.AbstractSwaggerUiConfigProperties;
import org.springdoc.core.properties.SwaggerUiConfigProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import jakarta.annotation.PostConstruct;
import java.util.HashSet;
import java.util.Set;

@Configuration
public class SwaggerConfig {
    private final SwaggerUiConfigProperties swaggerUiConfigProperties;

    public SwaggerConfig(SwaggerUiConfigProperties swaggerUiConfigProperties) {
        this.swaggerUiConfigProperties = swaggerUiConfigProperties;
    }

    @Bean
    public OpenAPI customOpenAPI() {
        return new OpenAPI()
                .info(new Info()
                        .title("ScholarAI API Gateway")
                        .description(
                                "API Gateway for ScholarAI Microservices Platform. This gateway aggregates APIs from all microservices.")
                        .version("1.0")
                        .contact(new Contact()
                                .name("ScholarAI Development Team")
                                .email("dev@scholarai.com"))
                        .license(new License()
                                .name("MIT License")
                                .url("https://opensource.org/licenses/MIT")));
    }

    @PostConstruct
    public void init() {
        Set<AbstractSwaggerUiConfigProperties.SwaggerUrl> urls = new HashSet<>();

        // Manually define the service URLs based on the services we know exist
        urls.add(new AbstractSwaggerUiConfigProperties.SwaggerUrl(
                "User Service API",
                "/user-service/v3/api-docs",
                null));

        urls.add(new AbstractSwaggerUiConfigProperties.SwaggerUrl(
                "Notification Service API",
                "/notification-service/v3/api-docs",
                null));

        swaggerUiConfigProperties.setUrls(urls);
    }
}
