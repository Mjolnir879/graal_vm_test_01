# Etapa 1: Build da imagem nativa com GraalVM
FROM ghcr.io/graalvm/native-image-community:21 AS builder

# Instalar dependências necessárias para compilação nativa no Linux
RUN microdnf install -y gcc glibc-devel zlib-devel libstdc++-static

WORKDIR /build

# Copia os arquivos do Maven Wrapper e o pom.xml
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .

# Torna o wrapper executável
RUN chmod +x ./mvnw

# Baixa dependências (cache)
RUN ./mvnw dependency:go-offline -B

# Copia o código-fonte
COPY src ./src

# --- AJUSTE AQUI ---
# Para não ignorar AOT e buildar nativamente:
# 1. 'process-aot' é chamado automaticamente pelo 'native:compile' no Spring Boot 3+
# 2. Removamos o 'package' solto para evitar builds duplos (jar + native)
RUN ./mvnw clean native:compile -Pnative -B -DskipTests

# Etapa 2: Imagem final ultra-reduzida
# Usando distroless ou uma base mínima para maior performance e segurança
FROM ubuntu:22.04

WORKDIR /app

# Bibliotecas necessárias para rodar o binário (dynamic linking)
RUN apt-get update && apt-get install -y libstdc++6 libc6 && rm -rf /var/lib/apt/lists/*

# Copia o binário gerado (o nome 'demo' vem do seu <artifactId> no pom.xml)
COPY --from=builder /build/target/demo /app/demo

EXPOSE 8080

ENTRYPOINT ["/app/demo"]