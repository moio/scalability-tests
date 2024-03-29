locals {
  project_name = "st"

  upstream_cluster = {
    name           = "upstream"
    server_count   = 1
    agent_count    = 0
    distro_version = "v1.26.9+k3s1"
  }

  downstream_clusters = [
    for i in range(1) :
    {
      name           = "downstream-${i}"
      server_count   = 1
      agent_count    = 0
      distro_version = "v1.26.9+k3s1"
    }
  ]

  tester_cluster = {
    name           = "tester"
    server_count   = 1
    agent_count    = 0
    distro_version = "v1.26.9+k3s1"
  }

  clusters = concat([local.upstream_cluster], local.downstream_clusters, [local.tester_cluster])

  // k3d-specific
  first_kubernetes_api_port = 6445
  first_app_http_port       = 8080
  first_app_https_port      = 8443
}
