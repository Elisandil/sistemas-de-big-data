# Etapa 1: Compilación con Maven
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app

# Desbloquear repos HTTP para dependencias transitivas de Hive
COPY settings.xml /root/.m2/settings.xml

# Copiar pom.xml y dependencia local para cachear dependencias
COPY pom.xml .
COPY lib/ lib/

# Instalar JAR local en el repositorio Maven del contenedor
RUN mvn install:install-file \
    -Dfile=lib/hive-jdbc-2.3.2.jar \
    -DgroupId=org.apache.hive \
    -DartifactId=hive-jdbc \
    -Dversion=2.3.2 \
    -Dpackaging=jar \
    -DgeneratePom=true

# Descargar dependencias (aprovecha cache de Docker)
RUN mvn dependency:resolve -q

# Copiar código fuente y compilar
COPY src/ src/
RUN mvn clean package -q -DskipTests

# Etapa 2: Ejecución ligera
FROM eclipse-temurin:17-jre
WORKDIR /app

COPY --from=build /app/target/ventas-bi-1.0.0-jar-with-dependencies.jar app.jar

# Variable de entorno para conectar a Hive por la red Docker
ENV HIVE_JDBC_URL=jdbc:hive2://hive-server:10000/default

# Directorio de salida para el PDF
RUN mkdir -p /output

# Modo headless por defecto
ENTRYPOINT ["java", "-jar", "app.jar", "--headless", "/output/VentasPorCategoria.pdf"]
