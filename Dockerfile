# Etapa 1: Build nativo — usa imagem Graal com Maven embutido
# Nota: ghcr.io/graalvm/native-image-community:21 é baseada no OL9 mas pode
# ter conflitos de glibc. Usamos a variante "muslib" ou instalamos Maven via curl
FROM ghcr.io/graalvm/native-image-community:21 AS graalvm

# Baixa o Maven sem precisar do microdnf (evita conflito glibc)
RUN curl -fsSL https://archive.apache.org/dist/maven/maven-3/3.9.6/binaries/apache-maven-3.9.6-bin.tar.gz \
    | tar -xzC /opt \
    && ln -sf /opt/apache-maven-3.9.6/bin/mvn /usr/local/bin/mvn

WORKDIR /build

# Baixa dependências (cache Docker separado do código-fonte)
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copia o código-fonte
COPY src ./src

# 1) 'package' roda o spring-boot:process-aot (gera target/spring-aot/main/classes)
# 2) 'native:compile' lê o classpath configurado no pom.xml (incluindo o spring-aot)
#    e gera o executável nativo em target/demo
RUN mvn clean package native:compile -Pnative -B -DskipTests

# Etapa 2: Imagem de runtime mínima (~70 MB)
FROM ubuntu:22.04

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libstdc++6 libc6 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=graalvm /build/target/demo /app/demo
RUN chmod +x /app/demo

EXPOSE 8080

ENTRYPOINT ["/app/demo"]