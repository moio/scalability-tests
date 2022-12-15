output "rancher_help" {
  value = <<-EOT
    UPSTREAM CLUSTER ACCESS:
      export KUBECONFIG=../config/upstream.yaml

    RANCHER UI:
      https://${module.upstream_cluster.first_server_private_name}:3000
 EOT
}
