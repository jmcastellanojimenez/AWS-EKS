# Multi-stage build for Spring Boot application
FROM openjdk:17-jdk-slim as builder

WORKDIR /app
COPY pom.xml .
COPY src ./src

# Download dependencies
RUN apt-get update && apt-get install -y maven
RUN mvn dependency:go-offline -B

# Build application
RUN mvn clean package -DskipTests

FROM openjdk:17-jre-slim

# Install OpenTelemetry Java agent
RUN apt-get update && apt-get install -y curl && \
    curl -L -o /opt/opentelemetry-javaagent.jar \
    https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/latest/download/opentelemetry-javaagent.jar

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app

# Copy application jar
COPY --from=builder /app/target/*.jar app.jar

# Change ownership
RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# Run with OpenTelemetry instrumentation
ENTRYPOINT ["java", \
  "-javaagent:/opt/opentelemetry-javaagent.jar", \
  "-Dotel.service.name=user-service", \
  "-Dotel.resource.attributes=service.version=1.0.0", \
  "-jar", "app.jar"]