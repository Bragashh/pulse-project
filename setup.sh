set -e

echo "=================================================="
echo " Pulse — local environment setup"
echo "=================================================="

# ── Docker + compose plugin ───────────────────────────────────────────────────
if ! command -v docker >/dev/null 2>&1; then
    echo "→ Installing Docker..."
    sudo apt-get update -qq
    sudo apt-get install -y docker.io docker-compose-v2
    sudo systemctl enable --now docker
    sudo usermod -aG docker "$USER" || true
    echo "  Docker installed (you may need to log out/in for group changes)."
else
    echo "✓ Docker already present"
fi

# ── Python tooling ────────────────────────────────────────────────────────────
echo "→ Ensuring Python venv + pip..."
sudo apt-get install -y python3-pip python3-venv >/dev/null
echo "✓ Python tooling ready"

# Create the project virtualenv used by start.sh / tests
if [ ! -d ".venv" ]; then
    echo "→ Creating project virtualenv (.venv)..."
    python3 -m venv .venv
    . .venv/bin/activate
    pip install --quiet -r portal/backend/requirements.txt
    deactivate
    echo "✓ .venv created with backend requirements"
else
    echo "✓ .venv already exists"
fi

# ── minikube (local Kubernetes) ───────────────────────────────────────────────
if ! command -v minikube >/dev/null 2>&1; then
    echo "→ Installing minikube..."
    curl -sLO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    sudo install minikube-linux-amd64 /usr/local/bin/minikube
    rm -f minikube-linux-amd64
    echo "✓ minikube installed"
else
    echo "✓ minikube already present"
fi

# ── kubectl ───────────────────────────────────────────────────────────────────
if ! command -v kubectl >/dev/null 2>&1; then
    echo "→ Installing kubectl..."
    KVER="$(curl -sL https://dl.k8s.io/release/stable.txt)"
    curl -sLO "https://dl.k8s.io/release/${KVER}/bin/linux/amd64/kubectl"
    sudo install -m 0755 kubectl /usr/local/bin/kubectl
    rm -f kubectl
    echo "✓ kubectl installed"
else
    echo "✓ kubectl already present"
fi

# ── Terraform ─────────────────────────────────────────────────────────────────
if ! command -v terraform >/dev/null 2>&1; then
    echo "→ Installing Terraform..."
    sudo apt-get install -y gnupg software-properties-common curl
    wget -O- https://apt.releases.hashicorp.com/gpg \
        | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
        | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
    sudo apt-get update -qq
    sudo apt-get install -y terraform
    echo "✓ Terraform installed"
else
    echo "✓ Terraform already present"
fi

# ── Ansible + collections ─────────────────────────────────────────────────────
if ! command -v ansible >/dev/null 2>&1; then
    echo "→ Installing Ansible..."
    sudo apt-get install -y ansible
    echo "✓ Ansible installed"
else
    echo "✓ Ansible already present"
fi

echo "→ Installing required Ansible collections..."
ansible-galaxy collection install -r ansible/requirements.yml >/dev/null
echo "✓ Collections installed"

# ── AWS CLI ───────────────────────────────────────────────────────────────────
if ! command -v aws >/dev/null 2>&1; then
    echo "→ Installing AWS CLI v2..."
    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    (cd /tmp && unzip -oq awscliv2.zip && sudo ./aws/install --update)
    echo "✓ AWS CLI installed"
else
    echo "✓ AWS CLI already present"
fi

echo ""
echo "=================================================="
echo " Setup complete."
echo ""
echo " Next steps:"
echo "   Local app:   ./start.sh"
echo "   AWS/Jenkins: see README (Terraform + Ansible sections)"
echo "=================================================="
