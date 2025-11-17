# Multi-stage Dockerfile for Money Transfer Application
# Stage 1: Build stage
FROM maven:3.9-eclipse-temurin-17-alpine AS builder

LABEL maintainer="workshop@example.com"
LABEL description="Money Transfer Application - Build Stage"

WORKDIR /build

# Copy pom.xml and download dependencies (cached layer)
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy source code and build
COPY src ./src
RUN mvn clean package -DskipTests -B && \
    mv target/*.jar target/app.jar

    
# Stage 2: Runtime stage
FROM eclipse-temurin:17-jre-alpine

LABEL maintainer="workshop@example.com"
LABEL description="Money Transfer Application - Production"
LABEL version="1.0.0"

# Install curl for health checks (needed for Loki/monitoring)
RUN apk add --no-cache curl

# Create non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy JAR from builder stage
COPY --from=builder /build/target/app.jar ./app.jar

# Change ownership to non-root user
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check with curl
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

# Set JVM options for container environment
ENV JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"

# Run application (logs go to STDOUT for Docker to capture)
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]