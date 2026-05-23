set -euo pipefail

JENKINS_URL="${JENKINS_URL:-}"
JENKINS_USER="${JENKINS_USER:-admin}"
JENKINS_TOKEN="${JENKINS_TOKEN:-admin}"
JOB_NAME="${JOB_NAME:-pulse-pipeline}"
IMAGE="pulse-url-shortener"

if [ -z "$JENKINS_URL" ]; then
    echo "ERROR: set JENKINS_URL, e.g. JENKINS_URL=http://<ec2-ip>:8080 ./deploy-local.sh"
    exit 1
fi

AUTH="-u ${JENKINS_USER}:${JENKINS_TOKEN}"
API="${JENKINS_URL}/job/${JOB_NAME}/lastBuild/api/json"

echo "→ Checking the latest Jenkins build status..."
RESULT=$(curl -fsSL $AUTH "$API" | python3 -c "import sys,json; print(json.load(sys.stdin).get('result',''))" 2>/dev/null || echo "UNREACHABLE")

if [ "$RESULT" = "UNREACHABLE" ]; then
    echo "ERROR: could not reach Jenkins at $JENKINS_URL. Is the EC2 up and the job run at least once?"
    exit 1
fi

if [ "$RESULT" != "SUCCESS" ]; then
    echo "REFUSING TO DEPLOY: latest Jenkins build result is '${RESULT}', not SUCCESS."
    echo "Run the '${JOB_NAME}' pipeline in Jenkins until it is green, then re-run this script."
    exit 1
fi

echo "  Jenkins build is green. Proceeding."

# ── Download the artifact the pipeline archived ───────────────────────────────
ARTIFACT_BASE="${JENKINS_URL}/job/${JOB_NAME}/lastSuccessfulBuild/artifact"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

echo "→ Downloading ${IMAGE}.tar from Jenkins..."
curl -fsSL $AUTH "${ARTIFACT_BASE}/${IMAGE}.tar" -o "${WORKDIR}/${IMAGE}.tar"

# ── Load the image into minikube ──────────────────────────────────────────────
echo "→ Loading ${IMAGE} into minikube..."
minikube image load "${WORKDIR}/${IMAGE}.tar"

# ── Deploy to minikube ─────────────────────────────────────────────────────────────
echo "→ Applying Kubernetes manifests..."
kubectl apply -f kubernetes/url-shortener/

echo "→ Restarting the deployment to pick up the new image..."
kubectl rollout restart deployment url-shortener -n url-shortener 2>/dev/null || true

echo ""
echo "=================================================="
echo " Deployed the Jenkins-built url-shortener to local minikube."
echo " Check status with:  kubectl get pods -n url-shortener"
echo "=================================================="
