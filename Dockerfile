# -------------------------------------------------------
# Stage 1: Build the GraalVM native image
# -------------------------------------------------------
FROM ghcr.io/graalvm/native-image-community:21 AS builder

WORKDIR /app

# Install Maven
RUN microdnf install -y maven && microdnf clean all

# Cache dependencies first
COPY pom.xml .
RUN mvn dependency:go-offline -B -q

# Copy source and build native image
# IMPORTANT: use 'package' (lifecycle phase) NOT 'native:compile' (direct goal).
# 'package' triggers the full lifecycle including generate-sources, where
# spring-boot:process-aot runs and generates DemoApplication__ApplicationContextInitializer.
# Calling 'native:compile' directly SKIPS those phases → class never generated → AotInitializerNotFoundException at runtime.
COPY src ./src
RUN mvn -Pnative -DskipTests -B package

# -------------------------------------------------------
# Stage 2: Minimal runtime image
# -------------------------------------------------------
FROM debian:bookworm-slim

WORKDIR /app

COPY --from=builder /app/target/demo .

EXPOSE 8080

ENTRYPOINT ["./demo"]