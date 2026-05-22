# EC2 module — one Ubuntu instance using its default public IP.
# No Elastic IP: the instance gets a public IP automatically in a default VPC,
# and `terraform destroy` tears everything down cleanly (nothing is retained).

resource "aws_instance" "this" {
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [var.security_group_id]

  tags = {
    Name = var.name
  }
}
