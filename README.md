## PROMOProject ##

#### OpenAPI/Swagger: http://localhost:8080/swagger-ui/index.html
#### KafkaUI: http://localhost:8084/ui/

## Building with minikube

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

## Local with Docker:

#### mvn clean install
#### docker build -t promoproject .
#### docker-compose up --build
#### docker-compose down -v

### Services
#### - MongoDB
#### - Kafka
#### - Kafka-UI