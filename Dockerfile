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

# Step 1: compile + process-aot
# SPRING_MAIN_WEB_APPLICATION_TYPE=NONE is inherited by the forked JVM, preventing
# Tomcat/Security from trying to start during AOT analysis (which would crash the fork)
RUN SPRING_MAIN_WEB_APPLICATION_TYPE=NONE \
    ./mvnw -Pnative -DskipTests -B prepare-package

# Step 2: merge spring-aot output into target/classes so native:compile-no-fork
# finds DemoApplication__ApplicationContextInitializer and AOT reflection config
# (native-image auto-discovers META-INF/native-image/** via classpath)
RUN cp -r target/spring-aot/main/classes/. target/classes/ && \
    cp -r target/spring-aot/main/resources/. target/classes/ && \
    echo "AOT classes + resources merged into target/classes"

# Step 3: native compilation — uses target/classes which now includes all AOT artifacts
RUN ./mvnw -Pnative -DskipTests -B native:compile-no-fork

# -------------------------------------------------------
# Stage 2: Minimal runtime image
# -------------------------------------------------------
FROM debian:bookworm-slim

WORKDIR /app

COPY --from=builder /app/target/demo .

EXPOSE 8080

ENTRYPOINT ["./demo"]