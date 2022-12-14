#!/usr/bin/env bash

set -xe

# HACK: work around https://github.com/k3s-io/k3s/issues/2306
sleep ${sleep_time}

# pre-shared secrets
mkdir -p /var/lib/rancher/k3s/server/tls/
cat >/var/lib/rancher/k3s/server/tls/client-ca.key <<EOF
${client_ca_key}
EOF
cat >/var/lib/rancher/k3s/server/tls/client-ca.crt <<EOF
${client_ca_cert}
EOF
cat >/var/lib/rancher/k3s/server/tls/server-ca.key <<EOF
${server_ca_key}
EOF
cat >/var/lib/rancher/k3s/server/tls/server-ca.crt <<EOF
${server_ca_cert}
EOF
cat >/var/lib/rancher/k3s/server/tls/request-header-ca.key <<EOF
${request_header_ca_key}
EOF
cat >/var/lib/rancher/k3s/server/tls/request-header-ca.crt <<EOF
${request_header_ca_cert}
EOF

mkdir -p /etc/rancher/k3s/
cat >/etc/rancher/k3s/config.yaml <<EOF
server: ${jsonencode(server_url)}
token: ${jsonencode(token)}
%{ if cluster_init ~}
cluster-init: true
%{ endif ~}
%{ if exec == "server" ~}
tls-san:
%{ for san in sans ~}
  - ${jsonencode(san)}
%{ endfor ~}
kube-controller-manager-arg: "node-cidr-mask-size=${node_cidr_mask_size}"
%{ endif ~}
kubelet-arg: "config=/etc/rancher/k3s/kubelet-custom.config"
EOF

cat > /etc/rancher/k3s/kubelet-custom.config <<EOF
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
maxPods: ${max_pods}
EOF

# installation
export INSTALL_K3S_VERSION=${distro_version}
export INSTALL_K3S_EXEC=${exec}
%{ if datastore_endpoint != null ~}
export K3S_DATASTORE_ENDPOINT="${datastore_endpoint}"
%{ endif ~}

curl -sfL https://get.k3s.io | sh -
