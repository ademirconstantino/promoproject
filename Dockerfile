FROM openjdk:11
ADD target/promoproject-1.0-SNAPSHOT.jar promoproject.jar
ENTRYPOINT ["java", "-jar","promoproject.jar"]
EXPOSE 8080