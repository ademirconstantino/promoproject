# PROMOProject

PROMOProject is a **Java 17 / Spring Boot 3** backend that exposes REST APIs documented with OpenAPI (Swagger), stores data in **MongoDB**, and publishes and consumes messages on **Apache Kafka**. It ships with a monitoring stack (Prometheus + Grafana) and runs on **Kubernetes** or **Docker Compose**.

This guide takes you from a fresh clone to every UI open in your browser, on **Linux** or **macOS**.

> **Quick start** — with the [prerequisites](#2-prerequisites) installed and a [cluster running](#3-start-a-local-kubernetes-cluster), one script does steps 4–6 for you. It deploys MongoDB and Kafka first, waits for them, then starts the app with a single replica, then Kafka UI and monitoring, and prints what is running:
>
> ```bash
> ./makeit.sh --forward          # build, push, deploy and open the UIs
> ./makeit.sh --skip-build       # deploy the image already on Docker Hub
> ./makeit.sh --no-monitoring    # lighter: no Prometheus/Grafana (saves ~1 GB RAM)
> ./makeit.sh --help             # all options
> ```
> Use your own image with `IMAGE=YOUR_DOCKERHUB_USER/promoproject:latest ./makeit.sh`.

---

## Contents

1. [What gets deployed](#1-what-gets-deployed)
2. [Prerequisites](#2-prerequisites)
3. [Start a local Kubernetes cluster](#3-start-a-local-kubernetes-cluster)
4. [Build the application image](#4-build-the-application-image)
5. [Deploy to Kubernetes](#5-deploy-to-kubernetes)
6. [Open the UIs on your machine](#6-open-the-uis-on-your-machine)
7. [Day-to-day commands](#7-day-to-day-commands)
8. [Shut down and clean up](#8-shut-down-and-clean-up)
9. [Troubleshooting](#9-troubleshooting)
10. [Alternative: Docker Compose (no Kubernetes)](#10-alternative-docker-compose-no-kubernetes)

---

## 1. What gets deployed

Everything runs inside a dedicated Kubernetes namespace called `promoproject`. The manifests live in the [`k8s/`](k8s/) folder:

| File | Component | In-cluster address | On your machine (after step 6) |
|---|---|---|---|
| `00-namespace.yaml` | Namespace `promoproject` | — | — |
| `10-mongodb.yaml` | MongoDB 7 (+ credentials Secret and 1 GiB volume) | `mongodb:27017` | — |
| `20-kafka.yaml` | Apache Kafka 3.9 (KRaft, single broker) | `kafka:9092` | — |
| `30-kafka-ui.yaml` | Kafka UI | `kafka-ui:8080` | http://localhost:8084/ui/ |
| `40-app.yaml` | **PROMOProject** | `promoproject:8080` | http://localhost:8080 |
| `50-monitoring.yaml` | Kafka exporter, MongoDB exporter, Prometheus, Grafana | `prometheus:9090`, `grafana:3000` | http://localhost:9090, http://localhost:3000 |

The services are internal to the cluster (`ClusterIP`). You reach them from your machine through `kubectl port-forward`, which works the same way on every cluster type and on both operating systems. The [`k8s/port-forward.sh`](k8s/port-forward.sh) script opens all the forwards at once.

> The old single-file `k8s-deployment.yaml` deploys only the app, with no MongoDB or Kafka, so the app cannot start correctly with it. Use the `k8s/` folder instead.

---

## 2. Prerequisites

| Tool | Why | Check |
|---|---|---|
| **JDK 17** | Compile the app | `java -version` → `17.x` |
| **Maven 3.9+** | Build the JAR | `mvn -v` |
| **Docker** | Build and push the image | `docker version` |
| **kubectl** | Talk to the cluster | `kubectl version --client` |
| **A Kubernetes cluster** | Run the stack | see step 3 |
| **A Docker Hub account** | Host the image the cluster pulls | `docker login` |

Leave about **4 GB of RAM** free for the cluster: Kafka, MongoDB and the Spring Boot app are the heavy parts.

### Linux

```bash
# Debian / Ubuntu
sudo apt update
sudo apt install -y openjdk-17-jdk maven

# Docker Engine (official script; it also creates the "docker" group)
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER      # then log out and back in

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install kubectl /usr/local/bin/kubectl && rm kubectl
```

If more than one JDK is installed, make 17 the default:

```bash
sudo update-alternatives --config java     # pick java-17
sudo update-alternatives --config javac
```

### macOS (Homebrew)

```bash
brew install openjdk@17 maven kubectl
brew install --cask docker                 # Docker Desktop; open it once after installing

# Point the shell to JDK 17
echo 'export JAVA_HOME=$(/usr/libexec/java_home -v 17)' >> ~/.zshrc
source ~/.zshrc
```

---

## 3. Start a local Kubernetes cluster

Pick **one** option. All of them work with the rest of this guide.

### Option A — k3s (Linux, recommended)

A lightweight cluster that runs as a system service and does not need Docker.

```bash
curl -sfL https://get.k3s.io | sh -

# Let kubectl use it as your normal user
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
chmod 600 ~/.kube/config
```

### Option B — Docker Desktop Kubernetes (macOS, recommended)

Docker Desktop → **Settings → Kubernetes → Enable Kubernetes → Apply & restart**. Then:

```bash
kubectl config use-context docker-desktop
```

### Option C — minikube (Linux or macOS)

```bash
# Linux:  curl -LO https://storage.googleapis.com/minikube/latest/minikube-linux-amd64 && sudo install minikube-linux-amd64 /usr/local/bin/minikube
# macOS:  brew install minikube
minikube start --cpus=4 --memory=6g
```

### Check the cluster

```bash
kubectl get nodes
```

You should see one node with status `Ready`. If you get `connection to the server localhost:8080 was refused`, kubectl has no cluster configured — see [Troubleshooting](#9-troubleshooting).

---

## 4. Build the application image

The cluster pulls the app image from Docker Hub. In the commands below, replace `YOUR_DOCKERHUB_USER` with your Docker Hub username.

```bash
git clone https://github.com/ademirconstantino/promoproject.git
cd promoproject

# 1. Build the JAR (creates target/promoproject-1.0-SNAPSHOT.jar)
mvn clean package -DskipTests

# 2. Build the image
docker build -t YOUR_DOCKERHUB_USER/promoproject:latest .

# 3. Push it
docker login
docker push YOUR_DOCKERHUB_USER/promoproject:latest
```

Then open [`k8s/40-app.yaml`](k8s/40-app.yaml) and set the `image:` line to your image:

```yaml
image: YOUR_DOCKERHUB_USER/promoproject:latest
```

> **Apple Silicon Mac + Linux (x86) cluster:** an image built on an M1/M2/M3 Mac is `arm64` and will not run on an `amd64` cluster. If the image has to run on both, build a multi-architecture image:
> ```bash
> docker buildx build --platform linux/amd64,linux/arm64 \
>   -t YOUR_DOCKERHUB_USER/promoproject:latest --push .
> ```
> If you build and run on the same Mac (Docker Desktop or minikube), the regular `docker build` is enough.

> **Just want to try it?** You can skip this step: `k8s/40-app.yaml` already points to the published image `ademirconstantino85/promoproject:latest`.

---

## 5. Deploy to Kubernetes

From the project root:

```bash
kubectl apply -f k8s/
```

Watch the pods start (Ctrl+C to stop watching):

```bash
kubectl -n promoproject get pods -w
```

Wait until **every pod shows `1/1 Running`**. This takes 1–3 minutes on the first run, because the images are downloaded. It is normal for `promoproject` to restart once or twice while Kafka and MongoDB are still starting.

```
NAME                                READY   STATUS    RESTARTS
grafana-xxxxx                       1/1     Running   0
kafka-xxxxx                         1/1     Running   0
kafka-exporter-xxxxx                1/1     Running   1
kafka-ui-xxxxx                      1/1     Running   0
mongodb-xxxxx                       1/1     Running   0
mongodb-exporter-xxxxx              1/1     Running   0
prometheus-xxxxx                    1/1     Running   0
promoproject-xxxxx                  1/1     Running   1
```

To check the app is healthy:

```bash
kubectl -n promoproject logs deploy/promoproject --tail=50
```

---

## 6. Open the UIs on your machine

```bash
chmod +x k8s/port-forward.sh     # first time only
./k8s/port-forward.sh
```

Leave this terminal open. While it runs, these addresses work in your browser:

| What | URL | Login |
|---|---|---|
| 📄 Swagger / OpenAPI UI | http://localhost:8080/swagger-ui/index.html | — |
| 📈 Metrics (Actuator / Prometheus format) | http://localhost:8080/actuator/prometheus | — |
| ❤️ Health | http://localhost:8080/actuator/health | — |
| 🛠 Kafka UI | http://localhost:8084/ui/ | — |
| 📊 Grafana | http://localhost:3000/dashboards | `admin` / `admin` |
| 🔥 Prometheus | http://localhost:9090 | — |

Press **Ctrl+C** in that terminal to close all the tunnels.

Grafana starts with Prometheus already configured as its data source. To get a ready-made dashboard: **Dashboards → New → Import**, enter ID `19004` (Spring Boot 3.x Statistics), pick the *Prometheus* data source and click **Import**.

<details>
<summary>Prefer opening the forwards by hand?</summary>

Run each one in its own terminal:

```bash
kubectl -n promoproject port-forward svc/promoproject 8080:8080
kubectl -n promoproject port-forward svc/kafka-ui     8084:8080
kubectl -n promoproject port-forward svc/grafana      3000:3000
kubectl -n promoproject port-forward svc/prometheus   9090:9090
```
</details>

---

## 7. Day-to-day commands

**Redeploy after changing the code**

```bash
mvn clean package -DskipTests
docker build -t YOUR_DOCKERHUB_USER/promoproject:latest .
docker push YOUR_DOCKERHUB_USER/promoproject:latest
kubectl -n promoproject rollout restart deployment/promoproject
kubectl -n promoproject rollout status deployment/promoproject
```

The deployment uses `imagePullPolicy: Always`, so the restart pulls the new `latest`.

**Useful commands**

```bash
kubectl -n promoproject get pods                          # status of everything
kubectl -n promoproject logs -f deploy/promoproject       # follow app logs
kubectl -n promoproject describe pod <pod-name>           # why a pod is not starting
kubectl -n promoproject exec -it deploy/promoproject -- sh   # shell inside the app container
kubectl -n promoproject exec -it deploy/mongodb -- mongosh -u admin -p admin123   # MongoDB shell
```

> **Tip:** to avoid typing `-n promoproject` every time:
> `kubectl config set-context --current --namespace=promoproject`

---

## 8. Shut down and clean up

```bash
# Pause the app only (keeps everything else running)
kubectl -n promoproject scale deployment/promoproject --replicas=0
kubectl -n promoproject scale deployment/promoproject --replicas=1    # bring it back

# Remove the whole stack, including MongoDB data
kubectl delete namespace promoproject
```

If you deployed the old `k8s-deployment.yaml` before, remove it as well:

```bash
kubectl delete -f k8s-deployment.yaml --ignore-not-found
```

Stopping the cluster itself:

| Cluster | Stop | Start again |
|---|---|---|
| k3s | `sudo systemctl stop k3s` | `sudo systemctl start k3s` |
| Docker Desktop | quit Docker Desktop | open Docker Desktop |
| minikube | `minikube stop` | `minikube start` |

---

## 9. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `The connection to the server localhost:8080 was refused` | kubectl has no cluster config (or you are running as `root`, which looks in `/root/.kube/config`) | Run as your normal user and redo the kubeconfig part of [step 3](#3-start-a-local-kubernetes-cluster). Check with `kubectl config get-contexts` |
| `permission denied while trying to connect to the docker API at unix:///var/run/docker.sock` | Your user is not in the `docker` group | `sudo groupadd docker` (if it does not exist), `sudo usermod -aG docker $USER`, then log out and back in |
| `Unit docker.service not found` | Docker was installed via snap, or only the client is installed | Install Docker Engine with `curl -fsSL https://get.docker.com \| sudo sh` |
| Pod in `ImagePullBackOff` | Wrong image name, or the image was not pushed | Check `image:` in `k8s/40-app.yaml` and run `docker push` again |
| Pod in `ImagePullBackOff` with `no matching manifest for linux/amd64` | Image built on Apple Silicon, cluster is x86 | Build with `docker buildx --platform linux/amd64,linux/arm64 ... --push` |
| `promoproject` in `CrashLoopBackOff` | Kafka or MongoDB not ready yet | Wait a minute; if it continues, read `kubectl -n promoproject logs deploy/promoproject --previous` |
| `mongodb` stuck in `Pending` | Cluster has no default StorageClass | `kubectl get storageclass` — k3s, minikube and Docker Desktop include one; other clusters may need one configured |
| `port-forward` error `address already in use` | Something else on your machine uses that port (often `docker compose`) | Stop it (`docker compose down`) or change the left-hand port in `k8s/port-forward.sh` |
| Kafka UI shows a blank page at `localhost:8084` | The UI is served under `/ui` | Open http://localhost:8084/ui/ (with the trailing `/ui/`) |
| `Unsupported class file major version` during `mvn package` | Maven is using a JDK other than 17 | `mvn -v` shows the Java in use; set `JAVA_HOME` to JDK 17 |

---

## 10. Alternative: Docker Compose (no Kubernetes)

For a quick run without a cluster:

```bash
mvn clean package -DskipTests
docker compose up --build -d
```

| What | URL |
|---|---|
| Swagger UI | http://localhost:8080/swagger-ui/index.html |
| Kafka UI | http://localhost:8081 |
| Grafana | http://localhost:3000 (`admin` / `admin`) |
| Prometheus | http://localhost:9090 |

Stop and remove everything (including data volumes):

```bash
docker compose down -v
```

> Do not run Compose and the Kubernetes port-forwards at the same time: both use ports 8080, 3000 and 9090.

---

## Configuration reference

The app reads its connection settings from environment variables. These are set for you in `k8s/40-app.yaml`:

| Variable | Kubernetes value | Default (local run) |
|---|---|---|
| `SPRING_DATA_MONGODB_HOST` | `mongodb` | `localhost` |
| `SPRING_DATA_MONGODB_PORT` | `27017` | `27017` |
| `SPRING_DATA_MONGODB_DATABASE` | `promoproject` | `promoproject` |
| `SPRING_DATA_MONGODB_USERNAME` / `_PASSWORD` | from Secret `mongodb-credentials` | `admin` / `admin123` |
| `KAFKA_BOOTSTRAP_SERVERS` | `kafka:9092` | `localhost:9092` |

> The credentials in this repository (`admin` / `admin123` for MongoDB, `admin` / `admin` for Grafana) are for local development only. Change them before deploying anywhere shared.
