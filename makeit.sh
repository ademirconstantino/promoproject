#!/usr/bin/env bash
# Builds PROMOProject and deploys the whole stack (k8s/) to the current Kubernetes cluster.
#
# Deployment order: 1) MongoDB and Kafka  2) the app  3) Kafka UI and monitoring,
# waiting for each step to be ready before starting the next one.
#
# Usage: ./makeit.sh [options]
#   -l, --local          Load the image straight into the cluster (k3s, minikube or
#                        Docker Desktop) instead of pushing it to Docker Hub
#   -s, --skip-build     Do not build the JAR or the image, only deploy
#   -t, --with-tests     Run the tests during the Maven build
#   -m, --no-monitoring  Skip Prometheus, Grafana and the exporters (saves ~1 GB RAM)
#   -c, --clean          Delete the namespace (including MongoDB data) before deploying
#   -f, --forward        Open the port-forwards (k8s/port-forward.sh) at the end
#   -h, --help           Show this help
#
# Environment:
#   IMAGE                Image to build and deploy (default: the one in k8s/40-app.yaml)
#   MONGO_IMAGE          MongoDB image (default: the one in k8s/10-mongodb.yaml, or
#                        mongo:4.4 with --local on a CPU without AVX, e.g. Core 2 Duo)
set -euo pipefail

cd "$(dirname "$0")"

NS=promoproject
APP=promoproject
MANIFESTS=k8s
TIMEOUT=600s
DEFAULT_IMAGE=$(awk '/image:/ && /promoproject/ {print $2; exit}' "$MANIFESTS/40-app.yaml")
DEFAULT_MONGO_IMAGE=$(awk '/image: mongo:/ {print $2; exit}' "$MANIFESTS/10-mongodb.yaml")
IMAGE=${IMAGE:-$DEFAULT_IMAGE}
MONGO_IMAGE=${MONGO_IMAGE:-}

LOCAL=false
BUILD=true
SKIP_TESTS=true
MONITORING=true
CLEAN=false
FORWARD=false

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mWARN: %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }
usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

# MongoDB 5.0+ refuses to start on CPUs without AVX
cpu_has_avx() {
  case "$(uname -s)" in
    Linux)  grep -qw avx /proc/cpuinfo ;;
    Darwin) sysctl -n machdep.cpu.features 2>/dev/null | grep -q AVX ;;
    *)      return 0 ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -l|--local)         LOCAL=true ;;
    -s|--skip-build)    BUILD=false ;;
    -t|--with-tests)    SKIP_TESTS=false ;;
    -m|--no-monitoring) MONITORING=false ;;
    -c|--clean)         CLEAN=true ;;
    -f|--forward)       FORWARD=true ;;
    -h|--help)          usage ;;
    *) die "unknown option: $1 (see --help)" ;;
  esac
  shift
done

require() { command -v "$1" >/dev/null 2>&1 || die "'$1' not found in PATH"; }

# --- Pre-flight checks ------------------------------------------------------
require kubectl
kubectl cluster-info >/dev/null 2>&1 \
  || die "kubectl cannot reach a cluster (context: $(kubectl config current-context 2>/dev/null || echo none)). See README, step 2.2 / 3.2."

CONTEXT=$(kubectl config current-context)

# Only look at this machine's CPU when the cluster runs on it
if [[ -z "$MONGO_IMAGE" ]]; then
  if $LOCAL && ! cpu_has_avx; then
    MONGO_IMAGE=mongo:4.4
    warn "this CPU has no AVX; using $MONGO_IMAGE instead of $DEFAULT_MONGO_IMAGE"
  else
    MONGO_IMAGE=$DEFAULT_MONGO_IMAGE
  fi
fi

log "Cluster context: $CONTEXT | image: $IMAGE | mongo: $MONGO_IMAGE"

if $BUILD; then
  require docker
  # Use sudo for docker only when the user is not in the docker group
  DOCKER=(docker)
  if ! docker info >/dev/null 2>&1; then
    if sudo docker info >/dev/null 2>&1; then
      DOCKER=(sudo docker)
      warn "running docker with sudo (add yourself to the 'docker' group to avoid it)"
    else
      die "cannot talk to Docker (is it running?)"
    fi
  fi

  if [[ -x ./mvnw ]]; then MVN=./mvnw; else require mvn; MVN=mvn; fi
  JAVA_MAJOR=$("$MVN" -v 2>/dev/null | awk -F'[ .]' '/^Java version/ {print $3; exit}')
  [[ "$JAVA_MAJOR" == "17" ]] || warn "Maven is using Java ${JAVA_MAJOR:-unknown}; this project targets JDK 17"

  # --- Build ----------------------------------------------------------------
  log "Building the JAR"
  MVN_ARGS=(clean package -B)
  $SKIP_TESTS && MVN_ARGS+=(-DskipTests)
  "$MVN" "${MVN_ARGS[@]}"

  log "Building the image $IMAGE"
  "${DOCKER[@]}" build -t "$IMAGE" .

  # --- Ship the image to the cluster ----------------------------------------
  if $LOCAL; then
    if [[ "$CONTEXT" == minikube ]]; then
      log "Loading the image into minikube"
      require minikube
      minikube image load "$IMAGE" --overwrite=true
    elif [[ "$CONTEXT" == docker-desktop ]]; then
      log "Docker Desktop shares the local image store, nothing to load"
    elif kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.kubeletVersion}' | grep -q k3s; then
      log "Importing the image into k3s (needs sudo)"
      require k3s
      "${DOCKER[@]}" save "$IMAGE" | sudo k3s ctr images import -
    else
      die "--local supports k3s, minikube and Docker Desktop; push the image instead (run without --local)"
    fi
  else
    log "Pushing $IMAGE"
    "${DOCKER[@]}" push "$IMAGE" || die "push failed: run '${DOCKER[*]} login', or use --local to skip the registry"
  fi
fi

# --- Deploy -----------------------------------------------------------------
# The legacy single-file manifest deploys only the app (no MongoDB/Kafka); remove it if present.
kubectl delete -f k8s-deployment.yaml --ignore-not-found >/dev/null 2>&1 || true

if $CLEAN; then
  log "Deleting namespace $NS"
  kubectl delete namespace "$NS" --ignore-not-found --wait=true
fi

# Substitutions are applied to the manifests on the fly, so a re-run does not
# flip the deployments back and forth (and restart MongoDB) every time.
SED_ARGS=(-e "s#image: $DEFAULT_IMAGE\$#image: $IMAGE#"
          -e "s#image: $DEFAULT_MONGO_IMAGE\$#image: $MONGO_IMAGE#")
# imagePullPolicy: Always would ignore the image we just loaded into the cluster
$LOCAL && SED_ARGS+=(-e "s#imagePullPolicy: Always#imagePullPolicy: IfNotPresent#")

apply() {
  for f in "$@"; do cat "$MANIFESTS/$f"; printf '\n---\n'; done \
    | sed "${SED_ARGS[@]}" \
    | kubectl apply -f -
}

# Waits for a deployment; on failure shows its pods and logs, then stops
wait_ready() {
  local dep
  for dep in "$@"; do
    if ! kubectl -n "$NS" rollout status "deployment/$dep" --timeout="$TIMEOUT"; then
      kubectl -n "$NS" get pods -l "app=$dep"
      kubectl -n "$NS" logs "deploy/$dep" --tail=30 2>/dev/null || true
      die "$dep did not become ready in $TIMEOUT (see above)"
    fi
  done
}

log "1/3  MongoDB and Kafka"
apply 00-namespace.yaml 10-mongodb.yaml 20-kafka.yaml
wait_ready mongodb kafka

log "2/3  $APP"
apply 40-app.yaml
if $BUILD; then
  kubectl -n "$NS" rollout restart "deployment/$APP"   # pick up the new image
fi
wait_ready "$APP"

if $MONITORING; then
  log "3/3  Kafka UI and monitoring"
  apply 30-kafka-ui.yaml 50-monitoring.yaml
  wait_ready kafka-ui prometheus grafana mongodb-exporter kafka-exporter
else
  log "3/3  Kafka UI (monitoring skipped)"
  apply 30-kafka-ui.yaml
  # Make sure monitoring from a previous run is not consuming memory
  kubectl delete -f "$MANIFESTS/50-monitoring.yaml" --ignore-not-found >/dev/null 2>&1 || true
  wait_ready kafka-ui
fi

kubectl -n "$NS" get pods

log "Stack is up"
if $FORWARD; then
  exec "$MANIFESTS/port-forward.sh"
else
  echo "Run ./$MANIFESTS/port-forward.sh to open the UIs on localhost."
fi
