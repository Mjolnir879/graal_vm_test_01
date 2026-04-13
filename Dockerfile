# Etapa 1: Build da imagem nativa com GraalVM
FROM ghcr.io/graalvm/native-image-community:21 AS builder

WORKDIR /build

# Copia os arquivos do Maven Wrapper e o pom.xml
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .

# Torna o wrapper executável e faz o download das dependências offline para aproveitamento de cache do Docker
RUN chmod +x ./mvnw
RUN ./mvnw dependency:go-offline -B

# Copia o código-fonte para dentro do container
COPY src ./src

# Compila o projeto construindo o executável nativo do GraalVM
# O parâmetro -Pnative ativa o perfil nativo do Spring / GraalVM
RUN ./mvnw clean package -Pnative -B

# Etapa 2: Rodar a aplicação em um sistema mínimo
FROM ubuntu:22.04

WORKDIR /app

# Atualiza e garante que bibliotecas de compilação C/C++ padrão necessárias pelo binário estejam presentes 
# (embora o GraalVM já tente linkar nativamente o máximo possível)
RUN apt-get update && apt-get install -y libc6 && rm -rf /var/lib/apt/lists/*

# Copia do estágio 'builder' apenas o binário compilado final
# Por padrão, o nome do arquivo gerado condiz com o <artifactId> no pom.xml
COPY --from=builder /build/target/demo /app/demo

# Dá permissão de execução
RUN chmod +x /app/demo

# Expõe a porta que o seu servidor Web vai usar
EXPOSE 8080

# Ponto de entrada rodando a aplicação
ENTRYPOINT ["/app/demo"]
