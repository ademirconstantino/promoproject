# 🛠️ PROMOProject

PROMOProject is a backend microservice developed in **Java 17** that provides APIs documented via OpenAPI/Swagger and integrates with **Apache Kafka** and **MongoDB**.  
It’s designed to be deployed locally or in containerized environments using **Docker**, **docker-compose**, **Minikube** and **Kubernetes**.

---

## 🚀 Features

- 📦 Java 17 backend using **Spring Boot**
- 🧠 API documentation with **OpenAPI / Swagger**
- 🐘 MongoDB persistence
- 🪵 Integrates **Apache Kafka**
- 🐳 Docker and Kubernetes support
- 🔄 Useful shell scripts for automation

## 📎 Demo & Docs

Once the application is running:

- 📄 **Swagger / OpenAPI UI**  
  `http://localhost:8080/swagger-ui/index.html`  
- 🛠 **Kafka UI**  
  `http://localhost:8084/ui/`
- 🛠 **Grafana**
  http://localhost:3000/dashboards
- 📄 **Metrics (Spring-Boot Actuator)**  
  http://localhost:8080/actuator/prometheus

> Make sure dependent services (MongoDB and Kafka) are running before accessing the UIs.

---

## ✅ Prerequisites

Install the following before running the project:

- 🔹 **JDK 17+**
- 🔹 **Apache Maven**
- 🔹 **Docker & Docker Compose**
- 🔹 **Minikube** (optional, for Kubernetes)
- 🔹 **kubectl** (if using Kubernetes)

---

## 🧩 Getting Started

Clone the repository:

```bash
git clone https://github.com/ademirconstantino/promoproject.git
cd promoproject

## Building with minikube

  ./mvn clean package -DskipTests
  docker build -t promoproject .
  docker tag promoproject $username/promoproject:latest
  docker push $username/promoproject:latest

  ## Warming-up
  kubectl apply -f k8s-deployment.yaml

  kubectl get pods
  kubectl logs deployment/promoproject-deployment
  kubectl apply -f k8s-deployment.yaml

  ## Shutdown

  kubectl delete -f k8s-deployment.yaml

  kubectl scale deployment promoproject-deployment --replicas=0
  kubectl delete pod promoproject-deployment-645756fbb9-wbs72
  kubectl delete service promoproject-service

## Local with Docker:

  mvn clean install
  docker build -t promoproject .
  docker compose up --build
  docker compose down -v