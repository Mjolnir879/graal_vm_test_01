# -------------------------------------------------------
# Stage 1: Build the GraalVM native image
# -------------------------------------------------------
FROM ghcr.io/graalvm/native-image-community:21 AS builder

WORKDIR /app

COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN chmod +x mvnw

# Cache dependencies
RUN ./mvnw dependency:go-offline -B -q

COPY src ./src

# Single-invocation build — critical for correct native compilation.
#
# Why SPRING_MAIN_WEB_APPLICATION_TYPE=NONE:
#   spring-boot:process-aot forks a JVM to run the app and analyze it.
#   In the Docker build environment the SERVLET context crashes the fork
#   immediately (bug/env-mismatch in Spring Boot 4.0.5 with GraalVM JDK).
#   NONE lets the fork complete and generate AOT sources + classes.
#
# Why single Maven invocation (not split into prepare-package + native:compile-no-fork):
#   process-aot registers target/spring-aot/main/resources into the Maven
#   project model IN MEMORY. native:compile-no-fork then reads that model
#   and adds the directory to -H:ConfigurationFileDirectories automatically,
#   which registers DemoApplication__ApplicationContextInitializer for
#   Class.forName() reflection at runtime. Split invocations lose this state.
RUN SPRING_MAIN_WEB_APPLICATION_TYPE=NONE \
    ./mvnw -Pnative -DskipTests -B package

# -------------------------------------------------------
# Stage 2: Minimal runtime image
# -------------------------------------------------------
FROM debian:bookworm-slim

WORKDIR /app

COPY --from=builder /app/target/demo .

EXPOSE 8080

ENTRYPOINT ["./demo"]