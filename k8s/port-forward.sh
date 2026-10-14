#!/usr/bin/env bash
# Opens every UI of the stack on localhost. Press Ctrl+C to close them all.
set -euo pipefail

NS=promoproject

forward() {
  # Re-open the tunnel if it drops (for example when a pod restarts)
  while true; do
    kubectl -n "$NS" port-forward "svc/$1" "$2" >/dev/null 2>&1 || true
    sleep 2
  done
}

trap 'kill 0' EXIT INT TERM

forward promoproject 8080:8080 &
forward kafka-ui     8084:8080 &
forward grafana      3000:3000 &
forward prometheus   9090:9090 &

cat <<'EOF'
Port-forwards are open (Ctrl+C to stop):

  Swagger UI   http://localhost:8080/swagger-ui/index.html
  Metrics      http://localhost:8080/actuator/prometheus
  Health       http://localhost:8080/actuator/health
  Kafka UI     http://localhost:8084/ui/
  Grafana      http://localhost:3000/dashboards   (admin / admin)
  Prometheus   http://localhost:9090
EOF

wait
