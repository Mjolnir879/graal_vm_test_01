# =============================================================================
# Estágio 1: Build nativo
# Usa a imagem oficial do GraalVM com native-image já instalado
# =============================================================================
FROM ghcr.io/graalvm/native-image-community:21 AS builder

# Instala Maven sem sobrescrever o JAVA_HOME que a imagem já define corretamente
ENV MAVEN_HOME=/opt/apache-maven-3.9.6
ENV PATH=$MAVEN_HOME/bin:$PATH

RUN curl -fsSL https://archive.apache.org/dist/maven/maven-3/3.9.6/binaries/apache-maven-3.9.6-bin.tar.gz \
    | tar -xzC /opt

# Verifica que o ambiente está correto antes de qualquer coisa
RUN echo "=== Java em uso ===" && java -version && \
    echo "=== native-image ===" && native-image --version && \
    echo "=== Maven ===" && mvn --version

WORKDIR /build

# ── Cache de dependências ────────────────────────────────────────────────────
COPY pom.xml .
RUN mvn dependency:go-offline -B -q

# ── Build nativo em dois goals explícitos ───────────────────────────────────
# Não confiamos no binding automático do lifecycle (-Pnative package) pois
# ele pode variar conforme a versão do plugin e do wrapper.
# Em vez disso, chamamos os goals diretamente na ordem correta:
#
#  1. spring-boot:process-aot  → gera target/spring-aot/ (o ApplicationContextInitializer)
#  2. native:compile           → lê o classpath completo (incluindo AOT) e gera o binário
#
# O -DskipTests evita que testes rodem durante o build nativo.
COPY src ./src
RUN mvn -Pnative -DskipTests -B \
        spring-boot:process-aot \
        native:compile

# Garante que o binário foi realmente gerado antes de prosseguir
RUN test -f /build/target/demo || \
    (echo "ERRO: binário nativo não foi gerado em target/demo" && \
     echo "Conteúdo de target/:" && ls -la /build/target/ && exit 1)

# =============================================================================
# Estágio 2: Imagem de runtime mínima
# =============================================================================
FROM ubuntu:22.04

# Dependências mínimas para executável nativo linkado dinamicamente (glibc)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libstdc++6 \
    libc6 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /build/target/demo /app/demo
RUN chmod +x /app/demo

EXPOSE 8080

ENTRYPOINT ["/app/demo"]