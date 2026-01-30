# 🛠️ PROMOProject

PROMOProject is a backend microservice developed in **Java 17** that provides APIs documented via OpenAPI/Swagger and integrates with **Apache Kafka** and **MongoDB**.  
It’s designed to be deployed locally or in containerized environments using **Docker**, **docker-compose**, **Minikube** and **Kubernetes**. :contentReference[oaicite:1]{index=1}

---

## 🚀 Features

- 📦 Java 17 backend using **Spring Boot**
- 🧠 API documentation with **OpenAPI / Swagger**
- 🐘 MongoDB persistence
- 🪵 Integrates **Apache Kafka**
- 🐳 Docker and Kubernetes support
- 🔄 Useful shell scripts for automation

---

## 📌 Table of Contents

1. [Demo & Docs](#demo--docs)  
2. [Prerequisites](#prerequisites)  
3. [Getting Started](#getting-started)  
4. [Running Locally](#running-locally)  
5. [Using Docker](#using-docker)  
6. [Kubernetes (Minikube)](#kubernetes-minikube)  
7. [Useful Scripts](#useful-scripts)  
8. [API Documentation](#api-documentation)  
9. [Contributing](#contributing)  
10. [License](#license)

---

## 📎 Demo & Docs

Once the application is running:

- 📄 **Swagger / OpenAPI UI**  
  `http://localhost:8080/swagger-ui/index.html`  
- 🛠 **Kafka UI**  
  `http://localhost:8084/ui/`

> Make sure dependent services (MongoDB and Kafka) are running before accessing the UIs. :contentReference[oaicite:2]{index=2}

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

## 🧩 OpenAPI/Swagger: http://localhost:8080/swagger-ui/index.html
## 🧩 KafkaUI: http://localhost:8084/ui/

## Building with minikube

```bash
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
    docker-compose up --build
    docker-compose down -v