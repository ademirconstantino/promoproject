#!/bin/bash
eval $(minikube docker-env)
./mvnw clean package -DskipTests
docker build -t promoproject .
kubectl delete -f k8s-deployment.yaml
kubectl apply -f k8s-deployment.yaml