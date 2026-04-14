# Etapa 1: Build da imagem nativa com GraalVM
FROM ghcr.io/graalvm/native-image-community:21 AS builder

# Instalar apenas o necessário. O 'gcc' e 'glibc-devel' base já costumam estar presentes.
# Adicionamos o zlib-devel que é essencial para o Spring Boot nativo.
RUN microdnf install -y zlib-devel

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

# Executa o build nativo
# O Spring Boot 3/4 processa o AOT automaticamente durante o 'native:compile'
RUN ./mvnw clean native:compile -Pnative -B -DskipTests

# Etapa 2: Imagem final (Runtime)
FROM ubuntu:22.04

WORKDIR /app

# Instala apenas as libs de runtime necessárias
RUN apt-get update && apt-get install -y libc6 libstdc++6 zlib1g && rm -rf /var/lib/apt/lists/*

# Copia o binário (ajuste 'demo' se o artifactId no pom.xml for diferente)
COPY --from=builder /build/target/demo /app/demo

EXPOSE 8080

ENTRYPOINT ["/app/demo", "--debug"]