# ---------------------------------------------------------------
# Backend image (Day 4) - two stages:
#   1. "build": Maven + JDK compile the code into a JAR
#   2. final  : only a Java runtime + the JAR (small, no build tools)
# ---------------------------------------------------------------

# ---- Stage 1: build ----
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app

# Download dependencies first: this layer is cached until pom.xml changes
COPY pom.xml .
RUN mvn -B -q dependency:go-offline

COPY src ./src
RUN mvn -B -q clean package -DskipTests

# ---- Stage 2: run ----
FROM eclipse-temurin:21-jre
WORKDIR /app

# Never run the app as root inside the container
RUN useradd --system --uid 1001 appuser
COPY --from=build /app/target/user-management-0.0.1-SNAPSHOT.jar app.jar
USER 1001

EXPOSE 8080
# Use up to 75% of the container's memory limit for the Java heap
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "app.jar"]
