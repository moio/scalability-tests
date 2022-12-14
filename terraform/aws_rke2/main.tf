module "server_nodes" {
  count                       = var.server_count
  source                      = "../aws_host"
  ami                         = var.ami
  instance_type               = var.instance_type
  availability_zone           = var.availability_zone
  project_name                = var.project_name
  name                        = "${var.name}-server-node-${count.index}"
  ssh_key_name                = var.ssh_key_name
  ssh_private_key_path        = var.ssh_private_key_path
  subnet_id                   = var.subnet_id
  vpc_security_group_id       = var.vpc_security_group_id
  ssh_bastion_host            = var.ssh_bastion_host
  ssh_tunnels                 = count.index == 0 ? concat([[var.k8s_api_ssh_tunnel_local_port, 6443]], var.additional_ssh_tunnels) : []
  host_configuration_commands = var.host_configuration_commands
}

module "agent_nodes" {
  count                       = var.agent_count
  source                      = "../aws_host"
  ami                         = var.ami
  instance_type               = var.instance_type
  availability_zone           = var.availability_zone
  project_name                = var.project_name
  name                        = "${var.name}-agent-node-${count.index}"
  ssh_key_name                = var.ssh_key_name
  ssh_private_key_path        = var.ssh_private_key_path
  subnet_id                   = var.subnet_id
  vpc_security_group_id       = var.vpc_security_group_id
  ssh_bastion_host            = var.ssh_bastion_host
  host_configuration_commands = var.host_configuration_commands
}

module "rke2" {
  source       = "../rke2"
  project      = var.project_name
  name         = var.name
  server_names = [for node in module.server_nodes : node.private_name]
  agent_names  = [for node in module.agent_nodes : node.private_name]
  sans         = var.sans

  ssh_private_key_path = var.ssh_private_key_path
  ssh_bastion_host     = var.ssh_bastion_host
  ssh_local_port       = var.k8s_api_ssh_tunnel_local_port

  distro_version      = var.distro_version
  max_pods            = var.max_pods
  node_cidr_mask_size = var.node_cidr_mask_size
}

output "first_server_private_name" {
  value = var.server_count > 0 ? module.server_nodes[0].private_name : null
}
