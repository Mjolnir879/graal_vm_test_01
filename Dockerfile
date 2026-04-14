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
COPY src ./src
RUN mvn -Pnative -DskipTests -B native:compile

# -------------------------------------------------------
# Stage 2: Minimal runtime image
# -------------------------------------------------------
FROM debian:bookworm-slim

WORKDIR /app

COPY --from=builder /app/target/demo .

EXPOSE 8080

ENTRYPOINT ["./demo"]