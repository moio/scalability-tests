terraform {
  required_version = "1.5.7"
  required_providers {
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


module "cluster" {
  count        = length(local.clusters)
  source       = "../../modules/ssh_k3s"
  project_name = local.project_name
  name         = local.clusters[count.index].name
  server_count = local.clusters[count.index].server_count
  agent_count  = local.clusters[count.index].agent_count
  agent_labels = local.clusters[count.index].reserve_node_for_monitoring ? [
    [{ key : "monitoring", value : "true" }]
  ] : []
  agent_taints = local.clusters[count.index].reserve_node_for_monitoring ? [
    [{ key : "monitoring", value : "true", effect : "NoSchedule" }]
  ] : []
  distro_version       = local.clusters[count.index].distro_version
  fqdns                = [for node in var.nodes[count.index] : node.fqdn]
  ssh_user             = var.ssh_user
  ssh_private_key_path = var.ssh_private_key_path
}
