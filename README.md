# PROMOProject

PROMOProject is a **Java 17 / Spring Boot 3** backend that exposes REST APIs documented with OpenAPI (Swagger), stores data in **MongoDB**, and publishes and consumes messages on **Apache Kafka**. It ships with a monitoring stack (Prometheus + Grafana) and runs on **Kubernetes** or **Docker Compose**.

This guide takes you from a fresh clone to every UI open in your browser. Pick the section for your operating system — **[Linux](#2-linux)** or **[macOS](#3-macos)** — then use the shared sections that follow.

---

## Contents

1. [What gets deployed](#1-what-gets-deployed)
2. [Linux](#2-linux)
3. [macOS](#3-macos)
4. [The `makeit.sh` script](#4-the-makeitsh-script)
5. [Open the UIs on your machine](#5-open-the-uis-on-your-machine)
6. [Day-to-day commands](#6-day-to-day-commands)
7. [Shut down and clean up](#7-shut-down-and-clean-up)
8. [Troubleshooting](#8-troubleshooting)
9. [Alternative: Docker Compose (no Kubernetes)](#9-alternative-docker-compose-no-kubernetes)
10. [Configuration reference](#10-configuration-reference)

---

## 1. What gets deployed

Everything runs inside a dedicated Kubernetes namespace called `promoproject`. The manifests live in the [`k8s/`](k8s/) folder:

| File | Component | In-cluster address | On your machine (after port-forward) |
|---|---|---|---|
| `00-namespace.yaml` | Namespace `promoproject` | — | — |
| `10-mongodb.yaml` | MongoDB 7 (+ credentials Secret and 1 GiB volume) | `mongodb:27017` | — |
| `20-kafka.yaml` | Apache Kafka 3.9 (KRaft, single broker) | `kafka:9092` | — |
| `30-kafka-ui.yaml` | Kafka UI | `kafka-ui:8080` | http://localhost:8084/ui/ |
| `40-app.yaml` | **PROMOProject** | `promoproject:8080` | http://localhost:8080 |
| `50-monitoring.yaml` | Kafka exporter, MongoDB exporter, Prometheus, Grafana | `prometheus:9090`, `grafana:3000` | http://localhost:9090, http://localhost:3000 |

The services are internal to the cluster (`ClusterIP`). You reach them from your machine through `kubectl port-forward`; the [`k8s/port-forward.sh`](k8s/port-forward.sh) script opens all the forwards at once.

Building and deploying is automated by [`makeit.sh`](makeit.sh) (see [section 4](#4-the-makeitsh-script)).

> The old single-file `k8s-deployment.yaml` deploys only the app, with no MongoDB or Kafka, so the app cannot start correctly with it. `makeit.sh` removes it from the cluster automatically if it is still there.

---

## 2. Linux

Commands below are for Debian / Ubuntu. Leave about **4 GB of RAM** free for the cluster.

### 2.1 Install the tools

| Tool | Why | Check |
|---|---|---|
| **JDK 17** | Compile the app | `java -version` → `17.x` |
| **Maven 3.9+** | Build the JAR | `mvn -v` |
| **Docker Engine** | Build the image | `docker version` |
| **kubectl** | Talk to the cluster | `kubectl version --client` |

```bash
sudo apt update
sudo apt install -y openjdk-17-jdk maven git

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

### 2.2 Start a local Kubernetes cluster

Pick **one** option.

**Option A — k3s (recommended)**: a lightweight cluster that runs as a system service.

```bash
curl -sfL https://get.k3s.io | sh -

# Let kubectl use it as your normal user
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
chmod 600 ~/.kube/config
```

**Option B — minikube**

```bash
curl -LO https://storage.googleapis.com/minikube/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64
minikube start --cpus=4 --memory=6g
```

Check the cluster — you should see one node with status `Ready`:

```bash
kubectl get nodes
```

### 2.3 Build and deploy

```bash
git clone https://github.com/ademirconstantino/promoproject.git
cd promoproject
chmod +x makeit.sh cleanup.sh k8s/port-forward.sh     # first time only

./makeit.sh --local --forward
```

`--local` builds the image and loads it straight into the cluster, so you do not need a Docker Hub account:

- **k3s**: the image is imported with `sudo k3s ctr images import`, so the script asks for your `sudo` password.
- **minikube**: the image is loaded with `minikube image load`.

`--forward` opens the UIs on localhost when the deploy finishes. Continue at [section 5](#5-open-the-uis-on-your-machine).

> Prefer to publish the image to Docker Hub instead? See [Pushing to Docker Hub](#pushing-to-docker-hub).

### 2.4 Old hardware (e.g. MacBook Core 2 Duo, 8 GB RAM)

The stack is tuned to fit in about **3.5 GB** (the sum of the memory limits in `k8s/`), so it runs on an old dual-core machine with 8 GB of RAM. Two things matter on that kind of hardware:

- **Run Linux, not macOS.** Core 2 Duo Macs stop at macOS 10.11–10.13, and current Docker Desktop does not run there. Install a 64-bit Linux (Ubuntu Server 24.04 or Debian 12 work well) and follow this Linux section.
- **No AVX.** MongoDB 5.0+ needs a CPU with AVX, which Core 2 Duo lacks. `./makeit.sh --local` detects this and deploys `mongo:4.4` instead of `mongo:7`, with no extra steps. To choose yourself, set `MONGO_IMAGE` (for example `MONGO_IMAGE=mongo:4.4 ./makeit.sh --local`).

Install k3s without Traefik (the stack does not use an ingress), which saves about 100 MB:

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik" sh -
```

Then set up the kubeconfig as in [2.2](#22-start-a-local-kubernetes-cluster) and run `./makeit.sh --local --forward`. Expect the first deploy to take **5–10 minutes**; the app is given up to 5 minutes to start before Kubernetes considers it stuck.

> Already ran `mongo:7` on that disk? MongoDB data files are not compatible with an older version. Start from an empty volume: `./makeit.sh --local --clean`.

---

## 3. macOS

Commands below use [Homebrew](https://brew.sh). Leave about **4 GB of RAM** free for the cluster (in Docker Desktop: **Settings → Resources**).

> **Old Intel Mac (Core 2 Duo)?** Current Docker Desktop does not run on it. Install Linux instead and see [2.4](#24-old-hardware-eg-macbook-core-2-duo-8-gb-ram).

### 3.1 Install the tools

| Tool | Why | Check |
|---|---|---|
| **JDK 17** | Compile the app | `java -version` → `17.x` |
| **Maven 3.9+** | Build the JAR | `mvn -v` |
| **Docker Desktop** | Build the image and run Kubernetes | `docker version` |
| **kubectl** | Talk to the cluster | `kubectl version --client` |

```bash
brew install openjdk@17 maven kubectl git
brew install --cask docker                 # Docker Desktop; open it once after installing

# Point the shell (and Maven) to JDK 17
echo 'export JAVA_HOME=$(/usr/libexec/java_home -v 17)' >> ~/.zshrc
source ~/.zshrc
```

### 3.2 Start a local Kubernetes cluster

Pick **one** option.

**Option A — Docker Desktop Kubernetes (recommended)**

Docker Desktop → **Settings → Kubernetes → Enable Kubernetes → Apply & restart**. Then:

```bash
kubectl config use-context docker-desktop
```

**Option B — minikube**

```bash
brew install minikube
minikube start --cpus=4 --memory=6g
```

Check the cluster — you should see one node with status `Ready`:

```bash
kubectl get nodes
```

### 3.3 Build and deploy

```bash
git clone https://github.com/ademirconstantino/promoproject.git
cd promoproject
chmod +x makeit.sh cleanup.sh k8s/port-forward.sh     # first time only

./makeit.sh --local --forward
```

`--local` builds the image and makes it available to the cluster without Docker Hub:

- **Docker Desktop**: the cluster shares Docker's image store, so nothing extra is needed.
- **minikube**: the image is loaded with `minikube image load`.

`--forward` opens the UIs on localhost when the deploy finishes. Continue at [section 5](#5-open-the-uis-on-your-machine).

> **Apple Silicon (M1/M2/M3/M4):** the image you build is `arm64`. That is fine for a cluster on the same Mac. If you push it to Docker Hub for an `amd64` (Intel / Linux) cluster, build a multi-architecture image instead of using `makeit.sh`:
> ```bash
> mvn clean package -DskipTests
> docker buildx build --platform linux/amd64,linux/arm64 \
>   -t YOUR_DOCKERHUB_USER/promoproject:latest --push .
> ```

---

## 4. The `makeit.sh` script

[`makeit.sh`](makeit.sh) builds the app and deploys the whole stack to the cluster `kubectl` is currently pointing at. It works the same on Linux and macOS.

What it does, in order:

1. Checks that `kubectl` reaches a cluster, that Docker is running and that Maven uses JDK 17.
2. Builds the JAR (`mvn clean package -DskipTests`).
3. Builds the Docker image, then pushes it to Docker Hub — or, with `--local`, loads it into the cluster.
4. Removes the legacy `k8s-deployment.yaml` resources if present, and applies everything in `k8s/` (switching to `mongo:4.4` on CPUs without AVX).
5. Restarts the app so it picks up the new image, waits for every deployment to be ready and lists the pods.

```bash
./makeit.sh [options]
```

| Option | What it does |
|---|---|
| `-l`, `--local` | Load the image into the cluster (k3s, minikube or Docker Desktop) instead of pushing it to Docker Hub |
| `-s`, `--skip-build` | Do not build the JAR or the image; only deploy |
| `-t`, `--with-tests` | Run the tests during the Maven build |
| `-c`, `--clean` | Delete the `promoproject` namespace before deploying (**erases MongoDB data**) |
| `-f`, `--forward` | Run `k8s/port-forward.sh` at the end |
| `-h`, `--help` | Show the help |

| Variable | What it does |
|---|---|
| `IMAGE` | Image to build and deploy. Default: the `image:` in `k8s/40-app.yaml` (`ademirconstantino85/promoproject:latest`) |
| `MONGO_IMAGE` | MongoDB image. Default: `mongo:7`, or `mongo:4.4` with `--local` on a CPU without AVX (see [2.4](#24-old-hardware-eg-macbook-core-2-duo-8-gb-ram)) |

Examples:

```bash
./makeit.sh --local                 # build + deploy on a local cluster
./makeit.sh --local --clean -f      # start from scratch and open the UIs
./makeit.sh --skip-build            # re-apply the manifests only
IMAGE=myuser/promoproject:latest ./makeit.sh    # build, push to Docker Hub and deploy
```

### Pushing to Docker Hub

Without `--local`, the script pushes the image, and the cluster pulls it from Docker Hub. This is what you need for a remote cluster. Use your own Docker Hub user:

```bash
docker login
IMAGE=YOUR_DOCKERHUB_USER/promoproject:latest ./makeit.sh
```

The script points the deployment at `IMAGE` with `kubectl set image`, so you do not have to edit `k8s/40-app.yaml`. To make it permanent, change the `image:` line in that file.

> **Just want to try it?** `./makeit.sh --skip-build` deploys the already published image `ademirconstantino85/promoproject:latest` without building anything.

---

## 5. Open the UIs on your machine

If you did not use `--forward`, open the tunnels with:

```bash
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

## 6. Day-to-day commands

**Redeploy after changing the code** — just run the script again:

```bash
./makeit.sh --local          # or without --local if you push to Docker Hub
```

**Useful commands**

```bash
kubectl -n promoproject get pods                          # status of everything
kubectl -n promoproject logs -f deploy/promoproject       # follow app logs
kubectl -n promoproject describe pod <pod-name>           # why a pod is not starting
kubectl -n promoproject exec -it deploy/promoproject -- sh   # shell inside the app container
kubectl -n promoproject exec -it deploy/mongodb -- mongosh -u admin -p admin123   # MongoDB shell (use "mongo" instead of "mongosh" on mongo:4.4)
```

> **Tip:** to avoid typing `-n promoproject` every time:
> `kubectl config set-context --current --namespace=promoproject`

---

## 7. Shut down and clean up

```bash
# Pause the app only (keeps everything else running)
kubectl -n promoproject scale deployment/promoproject --replicas=0
kubectl -n promoproject scale deployment/promoproject --replicas=1    # bring it back

# Remove the whole stack, including MongoDB data
kubectl delete namespace promoproject
```

### Full cleanup with `cleanup.sh`

[`cleanup.sh`](cleanup.sh) removes everything the build and the deploy created and leaves only the source files, so the next `./makeit.sh` starts from scratch. Use it to free memory and disk (for example when the node reports `DiskPressure`).

```bash
chmod +x cleanup.sh     # first time only
./cleanup.sh            # lists what it will delete and asks for confirmation
./cleanup.sh --yes      # no confirmation
```

What it removes:

| Where | What |
|---|---|
| Memory | The port-forwards, every pod of the stack (namespace `promoproject`) and the Docker Compose containers |
| Disk — data | The MongoDB volume in Kubernetes and the Compose volumes (**all data is lost**) |
| Disk — images | The stack's images (app, MongoDB 7 and 4.4, Kafka, Kafka UI, exporters, Prometheus, Grafana) from Docker **and** from the cluster: k3s (asks for `sudo`), minikube or Docker Desktop |
| Disk — build | The Docker build cache and the Maven `target/` folder |

Images from other projects are not touched. The Docker build cache is shared by every project on the machine, but it is only a cache and is rebuilt when needed. Maven's download cache (`~/.m2`) is kept, so the next build does not download every dependency again. The cluster itself (k3s, minikube, Docker Desktop) keeps running.

Build and deploy again with:

```bash
./makeit.sh --local
```

Stopping the cluster itself:

| OS | Cluster | Stop | Start again |
|---|---|---|---|
| Linux | k3s | `sudo systemctl stop k3s` | `sudo systemctl start k3s` |
| Linux / macOS | minikube | `minikube stop` | `minikube start` |
| macOS | Docker Desktop | quit Docker Desktop | open Docker Desktop |

---

## 8. Troubleshooting

**Any OS**

| Symptom | Cause | Fix |
|---|---|---|
| `kubectl cannot reach a cluster` (from `makeit.sh`) or `connection to the server localhost:8080 was refused` | kubectl has no cluster configured, or the cluster is stopped | Start the cluster and check `kubectl config get-contexts` / `kubectl get nodes` |
| `Maven is using Java XX` warning, or `Unsupported class file major version` | Maven is using a JDK other than 17 | `mvn -v` shows the Java in use; set `JAVA_HOME` to JDK 17 |
| `push failed` | Not logged in to Docker Hub, or no permission on that repository | `docker login`, set `IMAGE=YOUR_DOCKERHUB_USER/promoproject:latest`, or use `--local` |
| Pod in `ImagePullBackOff` | Wrong image name, or the image was not pushed | Run `./makeit.sh --local` on a local cluster, or check `IMAGE` and push again |
| `promoproject` in `CrashLoopBackOff` | Kafka or MongoDB not ready yet | Wait a minute; if it continues, read `kubectl -n promoproject logs deploy/promoproject --previous` |
| `makeit.sh` ends with `some deployments are not ready` | A pod did not start within 10 minutes | `kubectl -n promoproject get pods`, then `describe` / `logs` the failing one |
| `mongodb` in `CrashLoopBackOff`, log says the CPU lacks AVX | Old CPU (e.g. Core 2 Duo) with `mongo:7` | Deploy with `./makeit.sh --local` (auto-detects it) or `MONGO_IMAGE=mongo:4.4` |
| Every pod `Pending` or `Evicted`; `kubectl describe node` shows `DiskPressure` | The disk is (almost) full | Free space: `./cleanup.sh` (see [section 7](#full-cleanup-with-cleanupsh)), then `docker system prune -a` if you need more. Pods start again once disk usage is back under ~85% |
| `mongodb` stuck in `Pending` | Cluster has no default StorageClass | `kubectl get storageclass` — k3s, minikube and Docker Desktop include one |
| `port-forward` error `address already in use` | Another program uses that port (often `docker compose`) | Stop it (`docker compose down`) or change the left-hand port in `k8s/port-forward.sh` |
| Kafka UI shows a blank page at `localhost:8084` | The UI is served under `/ui` | Open http://localhost:8084/ui/ (with the trailing `/ui/`) |

**Linux**

| Symptom | Cause | Fix |
|---|---|---|
| `cannot talk to Docker` / `permission denied ... docker.sock` | Your user is not in the `docker` group | `sudo usermod -aG docker $USER`, then log out and back in |
| `Unit docker.service not found` | Docker installed via snap, or only the client is installed | Install Docker Engine with `curl -fsSL https://get.docker.com \| sudo sh` |
| `connection refused` when running as `root` | `root` looks in `/root/.kube/config` | Run `makeit.sh` as your normal user (it calls `sudo` only where needed) |
| `--local` on k3s asks for a password | Importing into k3s needs root | Type your `sudo` password; this is expected |

**macOS**

| Symptom | Cause | Fix |
|---|---|---|
| `cannot talk to Docker` | Docker Desktop is not running | Open Docker Desktop and wait until it says *running* |
| `kubectl get nodes` fails after enabling Kubernetes | Wrong context selected | `kubectl config use-context docker-desktop` |
| `no matching manifest for linux/amd64` on a remote cluster | Image built on Apple Silicon | Build a multi-arch image with `docker buildx` (see [3.3](#33-build-and-deploy)) |
| Pods `Pending` / evicted | Docker Desktop has too little memory | **Settings → Resources**: give it at least 6 GB |

---

## 9. Alternative: Docker Compose (no Kubernetes)

For a quick run without a cluster (Linux and macOS):

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

## 10. Configuration reference

The app reads its connection settings from environment variables. These are set for you in `k8s/40-app.yaml`:

| Variable | Kubernetes value | Default (local run) |
|---|---|---|
| `SPRING_DATA_MONGODB_HOST` | `mongodb` | `localhost` |
| `SPRING_DATA_MONGODB_PORT` | `27017` | `27017` |
| `SPRING_DATA_MONGODB_DATABASE` | `promoproject` | `promoproject` |
| `SPRING_DATA_MONGODB_USERNAME` / `_PASSWORD` | from Secret `mongodb-credentials` | `admin` / `admin123` |
| `KAFKA_BOOTSTRAP_SERVERS` | `kafka:9092` | `localhost:9092` |

> The credentials in this repository (`admin` / `admin123` for MongoDB, `admin` / `admin` for Grafana) are for local development only. Change them before deploying anywhere shared.
