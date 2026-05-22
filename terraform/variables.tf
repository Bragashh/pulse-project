variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-central-1"
}

variable "ami" {
  description = "AMI ID for the Jenkins EC2. Default is Ubuntu 24.04 in eu-central-1; change if you use another region."
  type        = string
  default     = "ami-0a628e1e89aaedf80"
}

variable "instance_type" {
  description = "EC2 instance type for Jenkins"
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "Name for the SSH key pair created in AWS"
  type        = string
  default     = "pulse-project-key"
}

variable "public_key_path" {
  description = "Path to your SSH public key on the local machine"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "security_group_name" {
  description = "Name for the security group"
  type        = string
  default     = "pulse-project-sg"
}

variable "ssh_cidr" {
  description = "CIDR allowed to SSH in. Open by default; set to YOUR_IP/32 to lock it down."
  type        = string
  default     = "0.0.0.0/0"
}
