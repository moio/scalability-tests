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
  }
}

provider "aws" {
  region = local.region
}

module "aws_shared" {
  source              = "./aws_shared"
  project_name        = local.project_name
  ssh_public_key_path = local.ssh_public_key_path
}

module "aws_network" {
  source                      = "./aws_network"
  region                      = local.region
  availability_zone           = local.availability_zone
  secondary_availability_zone = local.secondary_availability_zone
  project_name                = local.project_name
}

module "bastion" {
  depends_on            = [module.aws_network]
  source                = "./aws_host"
  ami                   = local.bastion_ami
  availability_zone     = local.availability_zone
  project_name          = local.project_name
  name                  = "bastion"
  ssh_key_name          = module.aws_shared.key_name
  ssh_private_key_path  = local.ssh_private_key_path
  subnet_id             = module.aws_network.public_subnet_id
  vpc_security_group_id = module.aws_network.public_security_group_id
}

module "etcd" {
  count                 = var.upstream_datastore == "etcd" ? 1 : 0
  depends_on            = [module.aws_network]
  source                = "./aws_etcd"
  ami                   = local.etcd_ami
  instance_type         = local.etcd_instance_type
  availability_zone     = local.availability_zone
  project_name          = local.project_name
  name                  = "etcd"
  server_count          = local.etcd_server_count
  ssh_key_name          = module.aws_shared.key_name
  ssh_private_key_path  = local.ssh_private_key_path
  ssh_bastion_host      = module.bastion.public_name
  subnet_id             = module.aws_network.private_subnet_id
  vpc_security_group_id = module.aws_network.public_security_group_id
}

module "postgres_kine" {
  count                 = var.upstream_datastore == "postgres" ? 1 : 0
  depends_on            = [module.aws_network]
  source                = "./aws_postgres_kine"
  ami                   = local.postgres_ami
  instance_type         = local.postgres_instance_type
  availability_zone     = local.availability_zone
  project_name          = local.project_name
  name                  = "postgres"
  ssh_key_name          = module.aws_shared.key_name
  ssh_private_key_path  = local.ssh_private_key_path
  ssh_bastion_host      = module.bastion.public_name
  subnet_id             = module.aws_network.private_subnet_id
  vpc_security_group_id = module.aws_network.public_security_group_id
  kine_executable       = var.kine_executable
}

module "upstream_cluster" {
  depends_on             = [module.etcd, module.postgres_kine]
  source                 = "./aws_k3s"
  ami                    = local.upstream_ami
  instance_type          = local.upstream_instance_type
  availability_zone      = local.availability_zone
  project_name           = local.project_name
  name                   = "upstream"
  server_count           = local.upstream_server_count
  agent_count            = local.upstream_agent_count
  ssh_key_name           = module.aws_shared.key_name
  ssh_private_key_path   = local.ssh_private_key_path
  ssh_bastion_host       = module.bastion.public_name
  subnet_id              = module.aws_network.private_subnet_id
  vpc_security_group_id  = module.aws_network.private_security_group_id
  additional_ssh_tunnels = [[3000, 443]]
  distro_version         = local.upstream_distro_version
  secondary_subnet_id    = module.aws_network.secondary_private_subnet_id
  datastore_endpoint = (
    var.upstream_datastore == "etcd" ? join(",", formatlist("http://%s:2379", module.etcd[0].server_names)) :
    var.upstream_datastore == "postgres" ? "http://${module.postgres_kine[0].private_name}:2379" :
    null
  )
}

module "k6" {
  depends_on            = [module.upstream_cluster]
  source                = "./aws_k6"
  availability_zone     = local.availability_zone
  project_name          = local.project_name
  name                  = "k6"
  ssh_key_name          = module.aws_shared.key_name
  ssh_private_key_path  = local.ssh_private_key_path
  ssh_bastion_host      = module.bastion.public_name
  subnet_id             = module.aws_network.private_subnet_id
  vpc_security_group_id = module.aws_network.public_security_group_id
}
