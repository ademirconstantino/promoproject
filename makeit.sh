#!/usr/bin/env bash
#
# makeit.sh — build PROMOProject and deploy the whole stack to Kubernetes.
#
# Order of deployment:
#   1. MongoDB and Kafka            (waits until both are ready)
#   2. PROMOProject, 1 replica      (waits until it is ready)
#   3. Kafka UI + monitoring        (Prometheus, Grafana, exporters)
#
# Usage:
#   ./makeit.sh                   build, push and deploy everything
#   ./makeit.sh --skip-build      deploy only (uses the image already on Docker Hub)
#   ./makeit.sh --no-monitoring   skip Prometheus, Grafana and the exporters (saves ~1 GB RAM)
#   ./makeit.sh --forward         open the UIs on localhost at the end
#   ./makeit.sh --clean           delete the namespace first (wipes MongoDB data)
#
# The image can be changed with:  IMAGE=myuser/promoproject:latest ./makeit.sh
#
set -euo pipefail

IMAGE="${IMAGE:-ademirconstantino85/promoproject:latest}"
NS="promoproject"
TIMEOUT="300s"

BUILD=true
MONITORING=true
FORWARD=false
CLEAN=false

for arg in "$@"; do
  case "$arg" in
    --skip-build)    BUILD=false ;;
    --no-monitoring) MONITORING=false ;;
    --forward)       FORWARD=true ;;
    --clean)         CLEAN=true ;;
    -h|--help)       sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $arg (use --help)"; exit 1 ;;
  esac
done

cd "$(dirname "$0")"

# ---------- helpers ----------
bold()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
ok()    { printf '    \033[32m✔\033[0m %s\n' "$*"; }
fail()  { printf '\n\033[31m✘ %s\033[0m\n' "$*" >&2; exit 1; }

wait_ready() {
  local dep="$1"
  printf '    waiting for %-18s ' "$dep..."
  if kubectl -n "$NS" rollout status "deployment/$dep" --timeout="$TIMEOUT" >/dev/null 2>&1; then
    printf '\033[32mready\033[0m\n'
  else
    printf '\033[31mnot ready\033[0m\n'
    echo
    kubectl -n "$NS" get pods -l "app=$dep"
    echo
    kubectl -n "$NS" logs "deploy/$dep" --tail=30 2>/dev/null || true
    fail "$dep did not become ready in $TIMEOUT. See the output above."
  fi
}

# Use sudo for docker only when the user is not in the docker group
DOCKER="docker"
if $BUILD && ! docker info >/dev/null 2>&1; then
  DOCKER="sudo docker"
fi

# ---------- checks ----------
bold "Checking tools and cluster"
command -v kubectl >/dev/null || fail "kubectl not found"
kubectl cluster-info >/dev/null 2>&1 \
  || fail "kubectl cannot reach a cluster. Is k3s/minikube running and ~/.kube/config set?"
ok "cluster: $(kubectl config current-context)"
if $BUILD; then
  command -v mvn >/dev/null || fail "mvn not found (install Maven)"
  javac -version 2>&1 | grep -q ' 17' || echo "    ! javac is not 17: $(javac -version 2>&1)"
  ok "build tools found"
fi

# ---------- build ----------
if $BUILD; then
  bold "Building JAR"
  mvn -q clean package -DskipTests
  ok "target/promoproject-1.0-SNAPSHOT.jar"

  bold "Building and pushing image $IMAGE"
  $DOCKER build -q -t "$IMAGE" . >/dev/null
  ok "image built"
  $DOCKER push -q "$IMAGE" >/dev/null || fail "push failed. Run '$DOCKER login' first."
  ok "image pushed"
fi

# ---------- deploy ----------
if $CLEAN; then
  bold "Removing previous deployment"
  kubectl delete namespace "$NS" --ignore-not-found --wait=true
  ok "namespace $NS removed"
fi

# Remove the old single-file deployment if it is still around
kubectl delete -f k8s-deployment.yaml --ignore-not-found >/dev/null 2>&1 || true

bold "1/3  MongoDB and Kafka"
kubectl apply -f k8s/00-namespace.yaml -f k8s/10-mongodb.yaml -f k8s/20-kafka.yaml >/dev/null
wait_ready mongodb
wait_ready kafka

bold "2/3  PROMOProject (1 replica)"
kubectl apply -f k8s/40-app.yaml >/dev/null
kubectl -n "$NS" set image deployment/promoproject promoproject="$IMAGE" >/dev/null
kubectl -n "$NS" scale deployment/promoproject --replicas=1 >/dev/null
# Always pull the freshly pushed :latest
kubectl -n "$NS" rollout restart deployment/promoproject >/dev/null
wait_ready promoproject

bold "3/3  Kafka UI$($MONITORING && echo ' and monitoring')"
kubectl apply -f k8s/30-kafka-ui.yaml >/dev/null
if $MONITORING; then
  kubectl apply -f k8s/50-monitoring.yaml >/dev/null
fi
wait_ready kafka-ui
if $MONITORING; then
  for dep in prometheus grafana mongodb-exporter kafka-exporter; do wait_ready "$dep"; done
else
  # Make sure monitoring from a previous run is not consuming memory
  kubectl delete -f k8s/50-monitoring.yaml --ignore-not-found >/dev/null 2>&1 || true
fi

# ---------- summary ----------
bold "Running services"
kubectl -n "$NS" get pods -o wide

cat <<EOF

Useful commands:
  kubectl -n $NS get pods -w                 watch the pods
  kubectl -n $NS logs -f deploy/promoproject follow the app logs
  ./k8s/port-forward.sh                      open the UIs on localhost
EOF

if $FORWARD; then
  bold "Opening port-forwards (Ctrl+C to stop)"
  exec ./k8s/port-forward.sh
fi
