FROM eclipse-temurin:17-jre

COPY target/promoproject-1.0-SNAPSHOT.jar promoproject.jar

EXPOSE 8080

# The heap is sized from the container memory limit instead of a fixed value
ENTRYPOINT ["java","-XX:MaxRAMPercentage=70","-jar","promoproject.jar"]
