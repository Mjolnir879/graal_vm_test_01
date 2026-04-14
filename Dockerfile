# -------------------------------------------------------
# Stage 1: Build the GraalVM native image
# -------------------------------------------------------
FROM ghcr.io/graalvm/native-image-community:21 AS builder

WORKDIR /app

# Copy Maven wrapper (downloads Maven 3.9.x — required for Spring Boot 4)
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN chmod +x mvnw

# Cache dependencies
RUN ./mvnw dependency:go-offline -B -q

COPY src ./src

# ── Step 1: compile + process-aot (generates AND compiles AOT sources)
#    process-aot runs with -Dspring.main.web-application-type=none (set in pom.xml)
#    so Tomcat/Security don't try to start during the forked JVM
RUN ./mvnw -Pnative -DskipTests -B prepare-package

# ── Step 2: merge AOT-generated classes into target/classes
#    native:compile-no-fork uses target/classes as classpath input;
#    this ensures DemoApplication__ApplicationContextInitializer is included
RUN cp -r target/spring-aot/main/classes/. target/classes/ 2>/dev/null \
    && echo "AOT classes merged into target/classes" \
    || echo "No AOT classes found — process-aot may have failed"

# ── Diagnostic (remove once working) ─────────────────────────────────────────
RUN echo "=== ALL files in target/spring-aot ===" && \
    find target/spring-aot -type f 2>/dev/null | sort || true
RUN echo "=== AOT Initializer in target/classes ===" && \
    find target/classes -name "*Initializer*" -o -name "*__*" 2>/dev/null | sort
# ─────────────────────────────────────────────────────────────────────────────

# ── Step 3: native compilation using target/classes (now includes AOT classes)
#    direct goal invocation — no lifecycle re-run, no overwrite of target/classes
RUN ./mvnw -Pnative -DskipTests -B native:compile-no-fork

# -------------------------------------------------------
# Stage 2: Minimal runtime image
# -------------------------------------------------------
FROM debian:bookworm-slim

WORKDIR /app

COPY --from=builder /app/target/demo .

EXPOSE 8080

ENTRYPOINT ["./demo"]