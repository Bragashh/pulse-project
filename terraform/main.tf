terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "networking" {
  source              = "./modules/networking"
  key_name            = var.key_name
  public_key_path     = var.public_key_path
  security_group_name = var.security_group_name
  ssh_cidr            = var.ssh_cidr
}

# Single EC2 that hosts Jenkins. The application itself runs locally on k3s;
# this machine exists to demonstrate the Terraform -> Ansible -> Jenkins toolchain.
module "jenkins" {
  source            = "./modules/ec2"
  name              = "pulse-project-jenkins"
  ami               = var.ami
  instance_type     = var.instance_type
  key_name          = module.networking.key_name
  security_group_id = module.networking.security_group_id
}
