# Stage 1 - compile the Java source with a full JDK
FROM eclipse-temurin:21-jdk AS build
WORKDIR /src
COPY HelloWorld.java ./
RUN javac HelloWorld.java

# Stage 2 - ship only the compiled class on a small JRE
FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /src/HelloWorld.class ./

EXPOSE 8080

CMD ["java", "HelloWorld"]
