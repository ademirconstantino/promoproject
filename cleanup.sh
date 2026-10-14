#!/usr/bin/env bash
# Removes everything makeit.sh and Docker Compose create, leaving only the source
# files needed to build again:
#   - stops the port-forwards (k8s/port-forward.sh)
#   - deletes the Kubernetes namespace, including the MongoDB volume
#   - stops the Docker Compose stack and deletes its containers and volumes
#   - deletes the stack's images from Docker and from the cluster (k3s or minikube)
#   - deletes the Docker build cache and the Maven output (target/)
#
# Images that do not belong to this stack are left alone. The Docker build cache
# is shared by every project on the machine; it is only a cache and is rebuilt.
#
# Usage: ./cleanup.sh [options]
#   -y, --yes    Do not ask for confirmation
#   -h, --help   Show this help
#
# Environment:
#   IMAGE        App image to delete (default: the one in k8s/40-app.yaml)
set -uo pipefail   # no -e: keep going when something is already gone

cd "$(dirname "$0")"

NS=promoproject
MANIFESTS=k8s
IMAGE=${IMAGE:-$(awk '/image:/ && /promoproject/ {print $2; exit}' "$MANIFESTS/40-app.yaml")}
ASSUME_YES=false

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mWARN: %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }
usage() { sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }
has()  { command -v "$1" >/dev/null 2>&1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)  ASSUME_YES=true ;;
    -h|--help) usage ;;
    *) die "unknown option: $1 (see --help)" ;;
  esac
  shift
done

# Every image the stack uses: the manifests, mongo:4.4 (no-AVX fallback),
# Docker Compose, the app image and anything else tagged */promoproject.
images() {
  {
    awk '/^ *image:/ {print $2}' "$MANIFESTS"/*.yaml
    echo mongo:4.4
    awk '/^ *image:/ {print $2}' docker-compose.yml | sed 's/^\${MONGO_IMAGE:-\(.*\)}$/\1/'
    echo "$IMAGE"
    if has docker; then
      docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -E '(^|/)promoproject[-_a-z]*:'
    fi
  } | sort -u
}

if ! $ASSUME_YES; then
  cat <<EOF
This removes:
  - the Kubernetes namespace "$NS" (all pods and the MongoDB data)
  - the Docker Compose stack, its containers and volumes
  - these images (from Docker and from the cluster, when present):
$(images | sed 's/^/      /')
  - the Docker build cache and the target/ folder
EOF
  read -r -p "Continue? [y/N] " answer
  [[ "$answer" =~ ^[yYsS]$ ]] || { echo "Nothing was removed."; exit 0; }
fi

# --- Running processes --------------------------------------------------------
log "Stopping port-forwards"
pkill -f "k8s/port-forward.sh" 2>/dev/null || true
pkill -f "kubectl -n $NS port-forward" 2>/dev/null || true

# --- Kubernetes ---------------------------------------------------------------
CLUSTER=none
if has kubectl && kubectl cluster-info >/dev/null 2>&1; then
  CONTEXT=$(kubectl config current-context)
  if [[ "$CONTEXT" == minikube ]]; then
    CLUSTER=minikube
  elif [[ "$CONTEXT" == docker-desktop ]]; then
    CLUSTER=docker-desktop
  elif kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.kubeletVersion}' 2>/dev/null | grep -q k3s; then
    CLUSTER=k3s
  else
    CLUSTER=other
  fi

  log "Deleting namespace $NS (context: $CONTEXT)"
  kubectl delete -f k8s-deployment.yaml --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete namespace "$NS" --ignore-not-found --wait=true --timeout=180s \
    || warn "namespace $NS is still terminating; run this script again later to free its images"
else
  warn "no Kubernetes cluster reachable; skipping the namespace and cluster images"
fi

# --- Docker Compose -----------------------------------------------------------
if has docker && docker info >/dev/null 2>&1; then
  log "Stopping the Docker Compose stack"
  if docker compose version >/dev/null 2>&1; then
    docker compose down --volumes --remove-orphans 2>/dev/null || true
  elif has docker-compose; then
    docker-compose down --volumes --remove-orphans 2>/dev/null || true
  fi
  DOCKER=true
else
  warn "Docker is not running; skipping Docker images and build cache"
  DOCKER=false
fi

# --- Images -------------------------------------------------------------------
IMAGES=$(images)

if $DOCKER; then
  log "Deleting images from Docker"
  for img in $IMAGES; do
    docker image inspect "$img" >/dev/null 2>&1 && docker rmi -f "$img" >/dev/null && echo "  removed $img"
  done
  # Untagged layers left behind by rebuilding promoproject:latest
  docker image prune -f >/dev/null

  log "Deleting the Docker build cache"
  docker builder prune -af >/dev/null && echo "  done"
fi

case "$CLUSTER" in
  k3s)
    if has k3s; then
      log "Deleting images from k3s (needs sudo)"
      for img in $IMAGES; do
        sudo k3s crictl rmi "$img" >/dev/null 2>&1 && echo "  removed $img"
      done
    else
      warn "k3s cluster detected but the k3s command is not on this machine; skipping its images"
    fi
    ;;
  minikube)
    log "Deleting images from minikube"
    for img in $IMAGES; do
      minikube image rm "$img" >/dev/null 2>&1 && echo "  removed $img"
    done
    ;;
  docker-desktop)
    : # same image store as Docker, already cleaned above
    ;;
  other)
    warn "images on this cluster's nodes are managed by the cluster; not removed"
    ;;
esac

# --- Build output -------------------------------------------------------------
log "Deleting build output (target/)"
rm -rf target && echo "  done"

log "Clean. Run ./makeit.sh to build and deploy again."
