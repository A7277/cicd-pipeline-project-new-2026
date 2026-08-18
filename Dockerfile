# ---- Dockerfile for the CI/CD demo app ----
# Jenkins builds the jar first (mvn package), then this Dockerfile just
# packages that already-built jar into a small runtime image.

FROM eclipse-temurin:11-jre-alpine

WORKDIR /app

# The jar produced by "mvn package" (see pom.xml finalName)
COPY target/demo-cicd-app.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
