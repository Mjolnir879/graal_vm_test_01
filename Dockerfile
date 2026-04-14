# -------------------------------------------------------
# Stage 1: Build the GraalVM native image
# -------------------------------------------------------
FROM ghcr.io/graalvm/native-image-community:21 AS builder

WORKDIR /app

# Copy Maven wrapper first (downloads Maven 3.9.x — required for Spring Boot 4)
# microdnf installs Maven 3.6.x which is incompatible with Spring Boot 4 AOT
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN chmod +x mvnw

# Cache dependencies (wrapper auto-downloads Maven 3.9 on first run)
RUN ./mvnw dependency:go-offline -B -q

# Copy source and build native image
# 'package' runs the full lifecycle:
#   prepare-package → spring-boot:process-aot (generates DemoApplication__ApplicationContextInitializer)
#   package         → native:compile-no-fork  (compiles binary with AOT classes on classpath)
COPY src ./src
RUN ./mvnw -Pnative -DskipTests -B -e package

# ── DIAGNOSTIC ─────────────────────────────────────────────────────────────
RUN echo "=== ALL files in target/spring-aot ===" && \
    find target/spring-aot -type f 2>/dev/null | sort || echo "!! spring-aot dir missing or empty"
RUN echo "=== AOT Initializer in target/classes? ===" && \
    find target/classes -name "*Initializer*" -o -name "*__*" 2>/dev/null | sort
# ────────────────────────────────────────────────────────────────────────────

# -------------------------------------------------------
# Stage 2: Minimal runtime image
# -------------------------------------------------------
FROM debian:bookworm-slim

WORKDIR /app

COPY --from=builder /app/target/demo .

EXPOSE 8080

ENTRYPOINT ["./demo"]