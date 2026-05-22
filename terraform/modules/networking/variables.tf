variable "key_name" {
  description = "Name for the SSH key pair in AWS"
  type        = string
  default     = "pulse-project-key"
}

variable "public_key_path" {
  description = "Path to the SSH public key file on the local machine"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "security_group_name" {
  description = "Name for the security group"
  type        = string
  default     = "pulse-project-sg"
}

variable "ssh_cidr" {
  description = "CIDR allowed to SSH in. Default is open; tighten to your IP/32 for safety."
  type        = string
  default     = "0.0.0.0/0"
}
