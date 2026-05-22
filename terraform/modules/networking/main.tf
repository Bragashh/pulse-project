# Networking module — SSH key pair and security group for the Jenkins EC2.

resource "aws_key_pair" "pulse_key" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

resource "aws_security_group" "pulse_sg" {
  name        = var.security_group_name
  description = "Allow SSH and Jenkins (8080) for Pulse"

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  # Jenkins web UI
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
