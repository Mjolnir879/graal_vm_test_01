# -------------------------------------------------------
# Stage 1: Build the GraalVM native image
# -------------------------------------------------------
FROM ghcr.io/graalvm/native-image-community:21 AS builder

WORKDIR /app

COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN chmod +x mvnw

RUN ./mvnw dependency:go-offline -B -q

COPY src ./src

# ── Step 1: compile + process-aot
# SPRING_MAIN_WEB_APPLICATION_TYPE=NONE → herdado pelo forked JVM via env,
# impede Tomcat/Security de tentarem iniciar durante a fase AOT
RUN SPRING_MAIN_WEB_APPLICATION_TYPE=NONE \
    ./mvnw -Pnative -DskipTests -B prepare-package

# ── Diagnóstico: onde foi parar o output do process-aot? ─────────────────────
# Checa target/spring-aot E target/generated-sources E qualquer DemoApplication* gerado
RUN echo "==== target/spring-aot (recursive) ====" && \
    ls -laR target/spring-aot/ 2>/dev/null || echo "(vazio ou ausente)"
RUN echo "==== target/generated-sources (recursive) ====" && \
    find target/generated-sources -type f 2>/dev/null | sort || echo "(nada)"
RUN echo "==== DemoApplication* anywhere in target ====" && \
    find target -name "DemoApplication*" 2>/dev/null | sort
RUN echo "==== All .class files NOT in target/classes or target/test-classes ====" && \
    find target -name "*.class" \
      ! -path "target/classes/*" \
      ! -path "target/test-classes/*" 2>/dev/null | sort | head -20
# ─────────────────────────────────────────────────────────────────────────────

# ── Step 2: merge AOT classes into target/classes (se existirem)
RUN cp -r target/spring-aot/main/classes/. target/classes/ 2>/dev/null \
    && echo "AOT classes merged" \
    || echo "No AOT classes to merge"

# ── Step 3: native compilation
RUN ./mvnw -Pnative -DskipTests -B native:compile-no-fork

# -------------------------------------------------------
# Stage 2: Minimal runtime image
# -------------------------------------------------------
FROM debian:bookworm-slim

WORKDIR /app

COPY --from=builder /app/target/demo .

EXPOSE 8080

ENTRYPOINT ["./demo"]