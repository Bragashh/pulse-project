# Pulse — Self-Service DevOps Platform

Pulse is a containerised web application that lets a developer deploy, promote,
and roll back services from a dashboard, backed by live observability
(Prometheus, Grafana, Loki). It runs locally on Kubernetes (k3s), and ships an
AWS toolchain — provisioned with Terraform, configured with Ansible — that
stands up a Jenkins CI/CD pipeline.

This README is a step-by-step operator guide. Run the commands in order.

---

## Architecture

![Pulse architecture](docs/architecture.svg)

The Jenkins pipeline on AWS builds and tests the image, then archives it. The local `deploy-local.sh` checks the build passed, pulls that exact image, and deploys it to k3s — so the cloud CI and the local cluster genuinely depend on each other.

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

## Quick Start (AWS CI/CD: Terraform → Ansible → Jenkins → k3s)

This is the connected pipeline. Terraform creates an EC2, Ansible installs
Jenkins on it, the Jenkins pipeline builds and tests the images and archives
them, and a local script pulls the tested image and deploys it to your k3s.
**k3s only ever runs an image that Jenkins built and tested.**

### Step 1 — Provision + configure (one script)

`provision-aws.sh` prompts for your AWS credentials (used for this shell session
only, never written to disk), runs Terraform to create the EC2, writes the IP
into the Ansible inventory, and runs Ansible to install Jenkins:

```bash
./provision-aws.sh
```

> Already ran `aws configure`? Just press Enter at the credential prompt and your
> existing credentials are used.

When it finishes it prints the Jenkins URL, e.g. `http://<ec2-ip>:8080`.

### Step 2 — Run the pipeline in Jenkins

Open `http://<ec2-ip>:8080` and log in with **admin / admin**. Run the
`pulse-pipeline` job. It checks out the repo, runs the 66 backend tests, builds
the images, and — on success — archives them as downloadable artifacts. A green
build is required for the next step.

### Step 3 — Deploy the tested image to local k3s

On your local machine:

```bash
JENKINS_URL=http://<ec2-ip>:8080 ./deploy-local.sh
```

This checks that the latest Jenkins build passed, downloads the image artifact,
imports it into k3s, and deploys it. If the build is not green, it refuses to
deploy — that's the dependency made real.

### Step 4 — Tear down (when finished)

```bash
cd terraform
terraform destroy         # type 'yes' — nothing is retained, no Elastic IP
```

A `t3.small` for an hour of testing costs only a few cents.

### Manual alternative (if you prefer not to use the script)

```bash
# credentials
export AWS_ACCESS_KEY_ID=...    # or run: aws configure
export AWS_SECRET_ACCESS_KEY=...

# terraform
cd terraform
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply

# ansible
cd ../ansible
ansible-galaxy collection install -r requirements.yml
cp inventory/jenkins.ini.example inventory/jenkins.ini
JENKINS_IP=$(terraform -chdir=../terraform output -raw jenkins_ip)
sed -i "s/JENKINS_EC2_IP/${JENKINS_IP}/" inventory/jenkins.ini
ansible-playbook playbook.yml
```

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
| Configuration management | Ansible |
| CI/CD | Jenkins (pipeline on AWS) + GitHub Actions (tests on every push) |
| Tests | pytest — 66 tests covering routes, DB, deploy/promote/rollback |

---

## Course requirements mapping

| # | Requirement | Where it's met |
| --- | --- | --- |
| 1 | Create machines with Terraform | `terraform/` — provisions the Jenkins EC2 (parameterised, no EIP) |
| 2 | Configure machines with Ansible | `ansible/` — installs + configures Jenkins via the `jenkins` role |
| 3 | CI/CD (Jenkins preferred) | Jenkins pipeline on AWS builds + tests + archives the image; `deploy-local.sh` deploys it to k3s; GitHub Actions also runs tests on push |
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
│   ├── group_vars/all.yml         (Jenkins admin user/password)
│   └── roles/jenkins/
├── .github/workflows/ci.yml  Runs the 66 tests on every push
├── Jenkinsfile               Pipeline: build → 66 tests → save + archive image
├── docs/architecture.svg     Architecture diagram
├── setup.sh                  One-time: install all prerequisites
├── provision-aws.sh          Prompt for creds → Terraform → Ansible (one command)
├── deploy-local.sh           Pull the Jenkins-tested image → deploy to k3s
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
