FROM eclipse-temurin:21-jdk AS build
WORKDIR /src
COPY Deployment.java ./
RUN javac Deployment.java

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /src/Deployment*.class ./
EXPOSE 4003
CMD ["java", "Deployment"]
