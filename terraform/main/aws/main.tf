terraform {
  required_version = ">= 1.3.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.63.0, <= 5.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.3, <= 5.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.7.1, <= 3.0.0"
    }
    ssh = {
      source  = "loafoe/ssh"
      version = ">= 2.2.1, <= 3.0.0"
    }
  }
}

provider "aws" {
  region  = local.region
  profile = "rancher-eng"
}

module "network" {
  source               = "../../modules/aws_network"
  project_name         = local.project_name
  region               = local.region
  ami                  = local.downstream_clusters[0].ami
  instance_type        = local.downstream_clusters[0].instance_type
  availability_zone    = local.availability_zone
  ssh_public_key_path  = var.ssh_public_key_path
  ssh_private_key_path = var.ssh_private_key_path
}

module "cluster" {
  count          = length(local.clusters)
  source         = "../../modules/aws_k3s"
  project_name   = local.project_name
  name           = local.clusters[count.index].name
  datastore      = try(local.clusters[count.index].name == "upstream" ? local.clusters[count.index].datastore : null, null)
  server_count   = local.clusters[count.index].server_count
  agent_count    = local.clusters[count.index].agent_count
  agent_labels   = local.clusters[count.index].agent_labels
  agent_taints   = local.clusters[count.index].agent_taints
  distro_version = local.clusters[count.index].distro_version

  sans                      = [local.clusters[count.index].local_name]
  local_kubernetes_api_port = local.first_local_kubernetes_api_port + count.index
  local_http_port           = local.first_local_http_port + count.index
  local_https_port          = local.first_local_https_port + count.index
  ami                       = local.clusters[count.index].ami
  instance_type             = local.clusters[count.index].instance_type
  availability_zone         = local.availability_zone
  ssh_key_name              = module.network.key_name
  ssh_private_key_path      = var.ssh_private_key_path
  ssh_bastion_host          = module.network.bastion_public_name
  subnet_id                 = module.network.private_subnet_id
  vpc_security_group_id     = module.network.private_security_group_id
  depends_on                = [module.network]
}
