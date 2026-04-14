# =============================================================================
# Estágio 1: Build nativo
# Usa a imagem oficial do GraalVM com native-image já instalado
# =============================================================================
FROM ghcr.io/graalvm/native-image-community:21 AS builder

# Instala Maven diretamente do repositório oficial da Apache
# e garante que o JAVA_HOME aponta para o GraalVM (não para outro JDK do PATH)
# Maven não está incluído na imagem — instala sem sobrescrever o JAVA_HOME
# que a própria imagem ghcr.io/graalvm/native-image-community já define corretamente
ENV MAVEN_HOME=/opt/apache-maven-3.9.6
ENV PATH=$MAVEN_HOME/bin:$PATH

RUN curl -fsSL https://archive.apache.org/dist/maven/maven-3/3.9.6/binaries/apache-maven-3.9.6-bin.tar.gz \
    | tar -xzC /opt

WORKDIR /build

# ── Cache de dependências ────────────────────────────────────────────────────
# Copia só o pom.xml primeiro para que o Docker só invalide o cache
# quando as dependências mudarem, não quando o código muda.
COPY pom.xml .
RUN mvn dependency:go-offline -B -q

# ── Build completo em um único comando ───────────────────────────────────────
# O perfil "native" (herdado do spring-boot-starter-parent) habilita
# AUTOMATICAMENTE as seguintes fases nesta ordem:
#   1. compile               – compila o código Java
#   2. spring-boot:process-aot – gera target/spring-aot/ com o initializer
#   3. package               – empacota incluindo as classes AOT
#   4. native:compile        – compila o executável nativo via GraalVM
#
# IMPORTANTE: usar "package" como goal (não "native:compile" standalone)
# garante que o lifecycle completo rode e as classes AOT estejam no classpath.
COPY src ./src
RUN mvn -Pnative package -DskipTests -B

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