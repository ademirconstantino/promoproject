#!/usr/bin/env bash
# Builds PROMOProject and deploys the whole stack (k8s/) to the current Kubernetes cluster.
#
# Usage: ./makeit.sh [options]
#   -l, --local          Load the image straight into the cluster (k3s, minikube or
#                        Docker Desktop) instead of pushing it to Docker Hub
#   -s, --skip-build     Do not build the JAR or the image, only deploy
#   -t, --with-tests     Run the tests during the Maven build
#   -c, --clean          Delete the namespace (including MongoDB data) before deploying
#   -f, --forward        Open the port-forwards (k8s/port-forward.sh) at the end
#   -h, --help           Show this help
#
# Environment:
#   IMAGE                Image to build and deploy (default: the one in k8s/40-app.yaml)
set -euo pipefail

cd "$(dirname "$0")"

NS=promoproject
APP=promoproject
MANIFESTS=k8s
DEFAULT_IMAGE=$(awk '/image:/ && /promoproject/ {print $2; exit}' "$MANIFESTS/40-app.yaml")
IMAGE=${IMAGE:-$DEFAULT_IMAGE}

LOCAL=false
BUILD=true
SKIP_TESTS=true
CLEAN=false
FORWARD=false

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mWARN: %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }
usage() { sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    -l|--local)      LOCAL=true ;;
    -s|--skip-build) BUILD=false ;;
    -t|--with-tests) SKIP_TESTS=false ;;
    -c|--clean)      CLEAN=true ;;
    -f|--forward)    FORWARD=true ;;
    -h|--help)       usage ;;
    *) die "unknown option: $1 (see --help)" ;;
  esac
  shift
done

require() { command -v "$1" >/dev/null 2>&1 || die "'$1' not found in PATH"; }

# --- Pre-flight checks ------------------------------------------------------
require kubectl
kubectl cluster-info >/dev/null 2>&1 \
  || die "kubectl cannot reach a cluster (context: $(kubectl config current-context 2>/dev/null || echo none)). See README, step 3."

CONTEXT=$(kubectl config current-context)
log "Cluster context: $CONTEXT | image: $IMAGE"

if $BUILD; then
  require docker
  docker info >/dev/null 2>&1 || die "cannot talk to Docker (is it running? is your user in the 'docker' group?)"

  if [[ -x ./mvnw ]]; then MVN=./mvnw; else require mvn; MVN=mvn; fi
  JAVA_MAJOR=$("$MVN" -v 2>/dev/null | awk -F'[ .]' '/^Java version/ {print $3; exit}')
  [[ "$JAVA_MAJOR" == "17" ]] || warn "Maven is using Java ${JAVA_MAJOR:-unknown}; this project targets JDK 17"

  # --- Build ----------------------------------------------------------------
  log "Building the JAR"
  MVN_ARGS=(clean package -B)
  $SKIP_TESTS && MVN_ARGS+=(-DskipTests)
  "$MVN" "${MVN_ARGS[@]}"

  log "Building the image $IMAGE"
  docker build -t "$IMAGE" .

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
      docker save "$IMAGE" | sudo k3s ctr images import -
    else
      die "--local supports k3s, minikube and Docker Desktop; push the image instead (run without --local)"
    fi
  else
    log "Pushing $IMAGE"
    docker push "$IMAGE" || die "push failed: run 'docker login', or use --local to skip the registry"
  fi
fi

# --- Deploy -----------------------------------------------------------------
# The legacy single-file manifest deploys only the app (no MongoDB/Kafka); remove it if present.
kubectl delete -f k8s-deployment.yaml --ignore-not-found >/dev/null 2>&1 || true

if $CLEAN; then
  log "Deleting namespace $NS"
  kubectl delete namespace "$NS" --ignore-not-found --wait=true
fi

log "Applying manifests from $MANIFESTS/"
kubectl apply -f "$MANIFESTS/00-namespace.yaml"
kubectl apply -f "$MANIFESTS/"

if [[ "$IMAGE" != "$DEFAULT_IMAGE" ]]; then
  kubectl -n "$NS" set image "deployment/$APP" "$APP=$IMAGE"
fi
if $LOCAL; then
  # The manifest uses imagePullPolicy: Always, which would ignore the image we just loaded
  kubectl -n "$NS" patch "deployment/$APP" --type=json \
    -p='[{"op":"replace","path":"/spec/template/spec/containers/0/imagePullPolicy","value":"IfNotPresent"}]'
fi

log "Restarting $APP to pick up the new image"
kubectl -n "$NS" rollout restart "deployment/$APP"

log "Waiting for the deployments (first run can take a few minutes)"
FAILED=false
for d in $(kubectl -n "$NS" get deployments -o name); do
  kubectl -n "$NS" rollout status "$d" --timeout=300s || FAILED=true
done

kubectl -n "$NS" get pods

if $FAILED; then
  warn "some deployments are not ready. Check: kubectl -n $NS logs deploy/$APP --tail=100"
  exit 1
fi

log "Stack is up"
if $FORWARD; then
  exec "$MANIFESTS/port-forward.sh"
else
  echo "Run ./$MANIFESTS/port-forward.sh to open the UIs on localhost."
fi
