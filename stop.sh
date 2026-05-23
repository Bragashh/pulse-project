set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "→ Stopping Flask backend..."
existing_pid=$(sudo ss -tlnp 2>/dev/null | grep ":5000 " | grep -oP 'pid=\K[0-9]+' | head -1 || true)
if [ -n "$existing_pid" ]; then
    kill "$existing_pid" && echo "  Flask stopped (pid $existing_pid)"
else
    echo "  (no Flask process found)"
fi

echo "→ Stopping monitoring stack..."
cd "$REPO_ROOT/monitoring"
sudo docker compose down

echo ""
echo "✓ Stopped. (minikube left running — stop manually with: minikube stop)"