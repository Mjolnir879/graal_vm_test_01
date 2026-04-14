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
RUN ./mvnw -Pnative -DskipTests -B package

# ── DIAGNOSTIC: remove these once the build works ──────────────────────────
# Did process-aot generate the initializer?
RUN echo "=== AOT generated classes ===" && \
    find target/spring-aot -name "*.class" 2>/dev/null || echo "!! target/spring-aot NOT FOUND"

# Is the initializer inside the native binary?
RUN echo "=== Checking binary for AOT initializer ===" && \
    strings target/demo | grep "ApplicationContextInitializer" || echo "!! Initializer NOT in binary"

# What is target/demo actually?
RUN echo "=== Binary info ===" && ls -la target/demo
# ───────────────────────────────────────────────────────────────────────────

# -------------------------------------------------------
# Stage 2: Minimal runtime image
# -------------------------------------------------------
FROM debian:bookworm-slim

WORKDIR /app

COPY --from=builder /app/target/demo .

EXPOSE 8080

ENTRYPOINT ["./demo"]