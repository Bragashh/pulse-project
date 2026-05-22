# Pulse — Self-Service DevOps Platform

Pulse is a containerised web application that lets a developer deploy, promote,
and roll back services from a dashboard, backed by live observability
(Prometheus, Grafana, Loki). It runs locally on Kubernetes (k3s), and ships an
AWS toolchain — provisioned with Terraform, configured with Ansible — that
stands up a Jenkins CI/CD pipeline.

This README is a step-by-step operator guide. Run the commands in order.

---

## Quick Start (local app)

Tested on Ubuntu 22.04 / 24.04 with at least 4 GB RAM. Every command included —
assumes a fresh machine.

```bash
# 1. Clone
git clone https://github.com/Bragashh/pulse-project.git
cd pulse-project

# 2. Make the scripts executable (zip/clone can drop the +x bit)
chmod +x setup.sh start.sh stop.sh simulate-traffic.sh

# 3. Install all prerequisites (Docker, k3s, kubectl, Terraform,
#    Ansible, AWS CLI, and the project virtualenv). Safe to re-run.
./setup.sh

# 4. Log out and back in once (so your user picks up the docker group),
#    OR run this to apply it in the current shell:
newgrp docker

# 5. Bring the stack up
./start.sh
```

When `start.sh` finishes it prints the URLs. Open:

- **Dashboard:** `http://localhost:5000/dashboard`
- **Grafana:** `http://localhost:3000` (admin / admin)
- **Prometheus:** `http://localhost:9090`

Generate some traffic so the Grafana panels show activity:

```bash
./simulate-traffic.sh        # Ctrl+C to stop
```

Stop everything:

```bash
./stop.sh
```

---

## Quick Start (AWS: Terraform → Ansible → Jenkins)

This stands up one EC2 on AWS and configures Jenkins on it. The application
itself stays local (above); this part demonstrates the infrastructure and CI/CD
toolchain.

### Step 1 — AWS credentials

Provide your own AWS credentials in the current shell (never committed):

```bash
export AWS_ACCESS_KEY_ID=your-key-id
export AWS_SECRET_ACCESS_KEY=your-secret
```

### Step 2 — Provision the EC2 with Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
#   open terraform.tfvars and set region / key_name / public_key_path if needed

terraform init
terraform apply           # type 'yes' to confirm
```

When it finishes, note the outputs:

```bash
terraform output jenkins_ip      # the EC2 public IP
terraform output jenkins_url     # http://<ip>:8080
```

### Step 3 — Configure Jenkins with Ansible

```bash
cd ../ansible

# Create the vault key file (demo password — see "Ansible Vault" below)
echo 'pulse-demo-vault-2026' > .vault_pass
chmod 600 .vault_pass

# Install the required Ansible collections
ansible-galaxy collection install -r requirements.yml

# Point the inventory at the EC2 you just created
cp inventory/jenkins.ini.example inventory/jenkins.ini
JENKINS_IP=$(terraform -chdir=../terraform output -raw jenkins_ip)
sed -i "s/JENKINS_EC2_IP/${JENKINS_IP}/" inventory/jenkins.ini

# Run the playbook
ansible-playbook playbook.yml
```

Ansible installs Java, Docker, the AWS CLI, and Jenkins; skips the setup wizard;
installs the Git + pipeline plugins; and seeds an `admin` user plus a
`pulse-pipeline` job from this repo's `Jenkinsfile`.

### Step 4 — Open Jenkins

Open the `jenkins_url` from Step 2 (`http://<ip>:8080`) and log in:

- **User:** `admin`
- **Password:** `admin`

Run the `pulse-pipeline` job. It checks out the repo, runs the 66 backend tests,
builds the three images, and — if you set a real `ECR_REGISTRY` (see below) —
pushes them to ECR. A green build means the whole chain works.

### Step 5 — Tear down (when finished)

```bash
cd ../terraform
terraform destroy         # type 'yes' — nothing is retained, no Elastic IP
```

---

## Pushing images to ECR (optional)

The Jenkins pipeline builds and tests by default. To also push images to your
own ECR, set these as environment variables on the Jenkins job (Manage Jenkins →
the job's configuration, or as global env vars):

```
ECR_REGISTRY = <your-account-id>.dkr.ecr.<region>.amazonaws.com
AWS_REGION   = <your-region>
```

Leave them unset (or as `CHANGE_ME`) and the push stage skips cleanly while
build + test still run.

---

## Running the tests directly

```bash
cd portal/backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python -m pytest -v          # 66 tests
```

---

## Ansible Vault

The Jenkins admin password is stored encrypted with Ansible Vault in
`ansible/group_vars/all/vault.yml` (committed, AES256). The vault **password**
is never committed — `.vault_pass` is gitignored, and you create it in Step 3.

> The values in this vault are **demonstration** credentials (`admin` / `admin`)
> and the vault password (`pulse-demo-vault-2026`) is published here on purpose,
> so the project can be graded and run. This demonstrates the Vault mechanism
> without protecting anything sensitive — real secrets would use a password
> supplied out-of-band, not written in a README.

---

## What the application does

The dashboard provides:

- **Service uptime monitoring** — add or remove monitored URLs from a form;
  latency and status update continuously.
- **Server health metrics** — CPU, memory, disk, with a calculated health score.
- **DORA metrics** — deployment frequency and change failure rate, from the
  GitHub Actions API of the source repo.
- **Self-service deploy** — enter a service name, image, port, replicas, and
  environment; click Deploy. Pulse calls the Kubernetes API and tracks the
  deployment from "deploying" to "healthy".
- **Promote staging to production** — one click deploys the same image to a
  parallel production deployment.
- **Rollback** — pick an older deployment from history and redeploy that image.
  The rollback is recorded as a new deployment, keeping an append-only audit trail.

The observability stack provides:

- **Prometheus** — request rate, latency histogram, server resources, services
  count, instrumented in the Flask app.
- **Grafana** — dashboards over the Prometheus and Loki data.
- **Loki + Promtail** — Docker container logs collected and queryable in Grafana.

---

## Tech stack

| Layer | Tools |
| --- | --- |
| Backend | Python 3.11, Flask, prometheus-client, kubernetes (Python client) |
| Frontend | HTML / CSS / JavaScript |
| Data | SQLite |
| Observability | Prometheus, Grafana, Loki, Promtail |
| Orchestration | k3s (lightweight Kubernetes) |
| Containers | Docker, docker-compose |
| Infrastructure as code | Terraform (modular) |
| Configuration management | Ansible (+ Ansible Vault) |
| CI/CD | Jenkins (pipeline on AWS) + GitHub Actions (tests on every push) |
| Tests | pytest — 66 tests covering routes, DB, deploy/promote/rollback |

---

## Course requirements mapping

| # | Requirement | Where it's met |
| --- | --- | --- |
| 1 | Create machines with Terraform | `terraform/` — provisions the Jenkins EC2 (parameterised, no EIP) |
| 2 | Configure machines with Ansible | `ansible/` — installs + configures Jenkins via the `jenkins` role + Vault |
| 3 | CI/CD (Jenkins preferred) | Jenkins pipeline (`Jenkinsfile`) on AWS; GitHub Actions also runs tests on push |
| 4 | Containerised app (docker-compose or k8s) | App runs on k3s; monitoring via docker-compose; all services have Dockerfiles |
| 5 | README explaining how to run / tech / what it does | This file |

---

## Project structure

```
pulse-project/
├── portal/
│   ├── backend/              Flask app, SQLite, deployer, metrics, tests
│   │   ├── app.py            Routes
│   │   ├── db.py             SQLite layer
│   │   ├── deployer.py       Kubernetes Python client wrapper
│   │   ├── metrics.py        Prometheus instrumentation
│   │   └── tests/            pytest suite (66 tests)
│   └── frontend/
│       └── index.html        Dashboard
├── kubernetes/
│   └── url-shortener/        Manifests for the example service
├── services/
│   └── url-shortener/        Flask app + Dockerfile for the example service
├── monitoring/               docker-compose stack
│   ├── docker-compose.yml    Prometheus, Grafana, Loki, Promtail
│   ├── prometheus.yml
│   └── promtail-config.yml
├── terraform/                Infrastructure as code
│   ├── main.tf               Single Jenkins EC2
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   └── modules/
│       ├── networking/       Key pair + security group (SSH + 8080)
│       └── ec2/              Instance (default public IP, clean teardown)
├── ansible/                  Jenkins provisioning
│   ├── playbook.yml
│   ├── ansible.cfg
│   ├── requirements.yml
│   ├── inventory/jenkins.ini.example
│   ├── group_vars/all/vault.yml   (encrypted)
│   └── roles/jenkins/
├── .github/workflows/ci.yml  Tests on push, optional ECR push
├── Jenkinsfile               Pipeline: build → 66 tests → push to ECR
├── docs/                     Architecture diagram, k3s setup notes
├── setup.sh                  One-time: install all prerequisites
├── start.sh                  Bring the local stack up
├── stop.sh                   Bring the local stack down
└── simulate-traffic.sh       Continuous traffic generation
```

---

## Troubleshooting

- **`./start.sh: Permission denied`** — run `chmod +x *.sh` (Step 2 of Quick Start).
- **`docker: permission denied`** — your user isn't in the docker group yet; run
  `newgrp docker` or log out and back in.
- **`start.sh` fails finding k3s/docker** — run `./setup.sh` first.
- **Ansible can't reach the EC2** — check `inventory/jenkins.ini` has the real IP,
  the instance is running, and your SSH key matches `key_name` in Terraform.
- **Jenkins not up after the playbook** — give it a minute; a t3.small is slow to
  boot Jenkins. Re-running `ansible-playbook playbook.yml` is safe (idempotent).

---

## License

MIT. See `LICENSE`.
