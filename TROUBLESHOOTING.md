Troubleshooting
Real issues encountered setting this project up, with the exact error text so you
can search for what you're seeing. Each entry: the error → why it happens → the fix.

bash: ./start.sh: Permission denied
Cause: the scripts lost their executable bit (cloning or copying files can
drop it).
Fix:
bashchmod +x *.sh
Once you git add + commit after this, the executable bit is recorded in the
repo, so it won't happen again for anyone who clones.

InvalidKeyPair.Duplicate: The keypair already exists / InvalidGroup.Duplicate: The security group 'pulse-project-sg' already exists
Cause: a previous run left the key pair and/or security group on AWS, and
Terraform's state no longer knows about them — so it tries to create them again
and AWS rejects the duplicates. Usually happens when terraform destroy didn't
fully run, or state was lost.
Fix — delete the orphaned resources, then re-provision. First terminate any
leftover instance (the security group can't be deleted while an instance uses
it):
bash# find and terminate the instance
aws ec2 describe-instances --region eu-central-1 \
  --filters "Name=tag:Name,Values=pulse-project-jenkins" "Name=instance-state-name,Values=running,stopped" \
  --query 'Reservations[].Instances[].InstanceId' --output text
aws ec2 terminate-instances --instance-ids <id> --region eu-central-1

# wait until it shows "terminated", then delete the key pair and SG
aws ec2 delete-key-pair --key-name pulse-project-key --region eu-central-1
SG=$(aws ec2 describe-security-groups --region eu-central-1 \
  --filters "Name=group-name,Values=pulse-project-sg" \
  --query 'SecurityGroups[].GroupId' --output text)
aws ec2 delete-security-group --group-id "$SG" --region eu-central-1

terraform state list is empty, or Error: Module not installed
Cause: Terraform commands act on the directory you run them from. If you run
from the wrong place, or .terraform/ was cleared, Terraform can't see its
modules or state.
Fix: always run Terraform from the terraform/ directory, and initialise
first:
bashcd terraform
terraform init
terraform state list
If state list is genuinely empty but a box is running on AWS, the state was
lost — check AWS directly (see the InvalidKeyPair.Duplicate entry) rather than
trusting the state file. The actual state lives in terraform/terraform.tfstate.

Jenkins never installs — NO_PUBKEY 7198F4B714ABFC68 / The repository ... is not signed
Cause: the official Jenkins apt repository's GPG signing keys are
expired/rotated. The keys published at the usual URLs no longer match what signs
the repo, so apt-get update rejects it and Jenkins can't be installed from apt.
Fix: this project deliberately does not use the apt repo. The Ansible
role downloads the latest LTS .deb directly from get.jenkins.io and installs
it with dpkg/apt, skipping GPG entirely. If you hit this doing a manual
install, do the same:
bashcd /tmp
curl -fsSL https://get.jenkins.io/debian-stable/ | grep -oP 'jenkins_[0-9.]+_all\.deb' | sort -V | tail -1
# download that filename, then:
sudo dpkg -i jenkins_<version>_all.deb || sudo apt-get install -f -y

Jenkins installed but won't start — Running with Java 17 ... which is older than the minimum required version (Java 21)
Cause: the current Jenkins LTS requires Java 21. If only Java 17 is present
(or it's the default), Jenkins exits immediately and systemd shows
Start request repeated too quickly / Failed with result 'exit-code'.
Fix: install Java 21 and point Jenkins at it. The Ansible role does this
automatically; manually:
bashsudo apt-get install -y openjdk-21-jre-headless
sudo systemctl edit jenkins
# add:
# [Service]
# Environment="JENKINS_JAVA_CMD=/usr/lib/jvm/java-21-openjdk-amd64/bin/java"
sudo systemctl daemon-reload
sudo systemctl restart jenkins

Plugin install fails — Cannot get CSRF / HTTP Error 403: Forbidden
Cause: installing plugins over Jenkins' HTTP API fails on a wizard-skipped
Jenkins — it can't obtain a CSRF crumb, and authentication state during first
setup makes it worse.
Fix: this project installs plugins with jenkins-plugin-cli (the official
offline tool that resolves dependencies and writes the plugin files directly), so
there's no API call and no CSRF to fail on. The Ansible role handles it. The key
detail if doing it by hand is the correct flag is --plugin-download-directory,
not --plugin-dir.

Grafana keeps restarting — Failed to provision data sources ... data source not found
Cause: an old, manually-created Grafana data source in the persistent volume
conflicts with the new provisioned one, and Grafana refuses to start.
Fix: wipe the Grafana volume so provisioning starts clean (you lose any
hand-made dashboards, but the provisioned ones reload automatically):
bashcd monitoring
docker compose down
docker volume ls | grep grafana          # find the exact name
docker volume rm <the-grafana-volume>
docker compose up -d

URL shortener shows "not deployed" even though you ran the deploy
Cause (most common): the image was deployed to the wrong cluster — e.g. you
still had k3s installed and the deploy went there, or to a cluster kubectl
isn't pointed at. Check what's actually running:
bashkubectl get pods -n url-shortener
If it says No resources found, it isn't deployed to the cluster you're looking
at. Make sure minikube is the active cluster (minikube status) and re-run
deploy-local.sh.
Cause (networking): the pod is running, but the backend can't reach it at the
address it's using. minikube's NodePort isn't always at the IP start.sh
guessed. Find the real URL and point the backend at it:
bashminikube service url-shortener -n url-shortener --url
export SHORTENER_URL=<that-url>
# restart the backend (re-run start.sh)

Grafana / dashboards don't load from another machine (only on the VM)
Cause: links built with localhost only work on the machine running the
services. From another machine, localhost points at that machine.
Fix: the dashboard buttons build their Grafana links from the host you're
viewing from (window.location.hostname), so they work both locally and
remotely — no hardcoded IP. For this to work from another machine, port 3000 (and
5000) must be reachable over the network, the same way you reach the dashboard.

Jenkins suddenly unreachable / deploy-local.sh hangs
Cause: the EC2 was destroyed (terraform destroy). deploy-local.sh first
calls the Jenkins API to check the build status; if Jenkins is gone, that call
hangs or fails.
Fix: this is expected after teardown — the AWS side only exists to build the
image. Always run deploy-local.sh (Step 5) before terraform destroy
(Step 6). Once the image is loaded into minikube, you no longer need Jenkins, and
destroying the EC2 is the correct, intended final step.

General tips (mistakes that I have made during my own TS-ing)

The Ansible playbook is idempotent — if it fails partway, fix the issue and
re-run it; it skips what's already done.
A fresh provision-aws.sh run gives a new EC2 IP. Always read it fresh:
terraform -chdir=terraform output -raw jenkins_ip.
Use the machine prompt to know where you are: user@user-... is your local
VM, ubuntu@ip-924-... is the EC2. Several issues above came from running a
command on the wrong machine.