#!/bin/bash
# provision-aws.sh — stand up the AWS side in one go.
#
# STEP 1: prompt for AWS credentials (kept in this shell session only, never
#         written to disk)
# STEP 2: Terraform creates the EC2
# STEP 3: inject the EC2 IP into the Ansible inventory automatically
# STEP 4: Ansible installs + configures Jenkins on it
#
# Alternative: if you already ran `aws configure`, just press Enter at the
# prompts and your configured credentials will be used.

set -euo pipefail

echo "=================================================="
echo " Pulse — provision AWS (Terraform + Ansible)"
echo "=================================================="
echo ""

# ── STEP 1: credentials ───────────────────────────────────────────────────────
echo "STEP 1/4 — AWS credentials"
echo "  (Leave blank to use credentials from 'aws configure' / environment.)"
read -rp "  AWS Access Key ID: " INPUT_KEY
if [ -n "$INPUT_KEY" ]; then
    read -rsp "  AWS Secret Access Key: " INPUT_SECRET
    echo ""
    export AWS_ACCESS_KEY_ID="$INPUT_KEY"
    export AWS_SECRET_ACCESS_KEY="$INPUT_SECRET"
    echo "  Using the credentials you entered (this session only)."
else
    echo "  Using existing AWS credentials from your environment / aws configure."
fi
echo ""

# ── STEP 2: Terraform ─────────────────────────────────────────────────────────
echo "STEP 2/4 — Terraform: provisioning the EC2..."
cd terraform
if [ ! -f terraform.tfvars ]; then
    cp terraform.tfvars.example terraform.tfvars
    echo "  Created terraform.tfvars from the example (edit it to change region/key)."
fi
terraform init -input=false
terraform apply -auto-approve
JENKINS_IP=$(terraform output -raw jenkins_ip)
cd ..
echo "  EC2 is up at ${JENKINS_IP}"
echo ""

# ── STEP 3: inventory ─────────────────────────────────────────────────────────
echo "STEP 3/4 — writing the Ansible inventory..."
cp ansible/inventory/jenkins.ini.example ansible/inventory/jenkins.ini
sed -i "s/JENKINS_EC2_IP/${JENKINS_IP}/" ansible/inventory/jenkins.ini
echo "  Inventory points at ${JENKINS_IP}"
echo ""

# ── STEP 4: Ansible ───────────────────────────────────────────────────────────
echo "STEP 4/4 — Ansible: installing + configuring Jenkins..."
echo "  (Give the EC2 ~30s to finish booting before SSH succeeds; retrying is safe.)"
cd ansible
ansible-galaxy collection install -r requirements.yml >/dev/null
# Retry the playbook a few times in case SSH/cloud-init isn't ready yet
for attempt in 1 2 3; do
    if ansible-playbook playbook.yml; then
        break
    fi
    echo "  Attempt ${attempt} failed (EC2 may still be booting). Retrying in 20s..."
    sleep 20
done
cd ..

echo ""
echo "=================================================="
echo " Done. Jenkins: http://${JENKINS_IP}:8080  (admin / admin)"
echo ""
echo " Next:"
echo "   1. Open Jenkins, run the 'pulse-pipeline' job until green"
echo "   2. Locally:  JENKINS_URL=http://${JENKINS_IP}:8080 ./deploy-local.sh"
echo "=================================================="
