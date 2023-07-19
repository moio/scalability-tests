terraform {
  required_version = "1.3.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.31.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.0.3"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.7.1"
    }
    ssh = {
      source  = "loafoe/ssh"
      version = "2.2.1"
    }
    k3d = {
      source  = "pvotal-tech/k3d"
      version = "0.0.6"
    }
  }
}

provider "aws" {
  region = local.region
}

module "network" {
  source               = "../../modules/aws_network"
  project_name         = local.project_name
  region               = local.region
  availability_zone    = local.availability_zone
  ssh_public_key_path  = local.ssh_public_key_path
  ssh_private_key_path = local.ssh_private_key_path
}
