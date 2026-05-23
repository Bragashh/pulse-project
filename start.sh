set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PULSE_DB="${PULSE_DB_PATH:-/tmp/pulse_smoke.db}"

cd "$REPO_ROOT"

echo "→ Checking minikube..."
if ! minikube status >/dev/null 2>&1; then
    echo "  Starting minikube..."
    minikube start --driver=docker
fi
kubectl get nodes >/dev/null && echo "  minikube OK"

# Discover how the backend should reach the in-cluster url-shortener (NodePort 30800).
MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "")
if [ -n "$MINIKUBE_IP" ]; then
    export SHORTENER_URL="http://${MINIKUBE_IP}:30800"
    echo "  Shortener will be reached at $SHORTENER_URL"
fi

echo "→ Ensuring UFW rule for port 5000..."
sudo ufw allow 5000/tcp >/dev/null 2>&1 || true

echo "→ Starting monitoring stack (Prometheus, Grafana, Loki, Promtail)..."
cd "$REPO_ROOT/monitoring"
sudo docker compose up -d
cd "$REPO_ROOT"

echo "→ Starting Flask backend in background..."
cd "$REPO_ROOT/portal/backend"
if [ -f "$REPO_ROOT/.venv/bin/activate" ]; then
    source "$REPO_ROOT/.venv/bin/activate"
fi
# Kill any existing Flask on port 5000
existing_pid=$(sudo ss -tlnp 2>/dev/null | grep ":5000 " | grep -oP 'pid=\K[0-9]+' | head -1 || true)
if [ -n "$existing_pid" ]; then
    echo "  Killing existing Flask process (pid $existing_pid)..."
    kill "$existing_pid" 2>/dev/null || true
    sleep 1
fi
PULSE_DB_PATH="$PULSE_DB" SHORTENER_URL="${SHORTENER_URL:-http://localhost:30800}" nohup python3 app.py > /tmp/pulse-backend.log 2>&1 &
FLASK_PID=$!
echo "  Flask started (pid $FLASK_PID), logs at /tmp/pulse-backend.log"
cd "$REPO_ROOT"

echo "→ Waiting for backend to be ready..."
for i in {1..15}; do
    if curl -sf http://localhost:5000/health >/dev/null 2>&1; then
        echo "  Backend OK"
        break
    fi
    sleep 1
done

VM_IP=$(ip addr show eth0 2>/dev/null | grep -oP 'inet \K[0-9.]+' | head -1)
echo ""
echo "✓ Stack is up:"
echo "  Dashboard:  http://${VM_IP:-localhost}:5000/dashboard"
echo "  Grafana:    http://${VM_IP:-localhost}:3000   (admin/admin)"
echo "  Prometheus: http://${VM_IP:-localhost}:9090"
echo ""
echo "To stop:   ./stop.sh"
echo "Backend logs: tail -f /tmp/pulse-backend.log"