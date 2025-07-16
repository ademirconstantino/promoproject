## PROMOProject ##

### I am creating this project to update my Java Development skills.
#### I started this project with spring-boot, spring-data, mongo-db. I hope this can be helpful. #

#### Added support to Kafka in 09/08/2024
#### OpenAPI/Swagger: http://localhost:8080/swagger-ui/index.html

### Building
#### ./mvnw clean package -DskipTests
#### docker build -t promoproject .
#### docker tag promoproject tuo-username/promoproject:latest
#### docker push tuo-username/promoproject:latest
#### kubectl apply -f k8s-deployment.yaml

#### kubectl get pods
#### kubectl logs deployment/promoproject-deployment
#### kubectl apply -f k8s-deployment.yaml

#### kubectl delete -f k8s-deployment.yaml

#### kubectl scale deployment promoproject-deployment --replicas=0
#### kubectl delete pod promoproject-deployment-645756fbb9-wbs72
#### kubectl delete service promoproject-service