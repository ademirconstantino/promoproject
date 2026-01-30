FROM eclipse-temurin:17-jdk

COPY target/promoproject-1.0-SNAPSHOT.jar promoproject.jar

EXPOSE 8080

ENTRYPOINT ["java","-Xms256m","-Xmx512m","-jar","promoproject.jar"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD curl -f http://localhost:8080/actuator/health || exit 1