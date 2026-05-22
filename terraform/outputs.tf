output "jenkins_ip" {
  description = "Public IP of the Jenkins EC2"
  value       = module.jenkins.public_ip
}

output "jenkins_url" {
  description = "Open this in a browser once Ansible has finished configuring Jenkins"
  value       = "http://${module.jenkins.public_ip}:8080"
}

output "ssh_command" {
  description = "SSH into the Jenkins host"
  value       = "ssh ubuntu@${module.jenkins.public_ip}"
}
