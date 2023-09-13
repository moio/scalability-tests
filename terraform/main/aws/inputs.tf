locals {
  project_name = var.project_name

  upstream_cluster = var.upstream_cluster

  downstream_clusters = var.num_downstreams > 0 ? [
    for i in range(var.num_downstreams) :
    merge(var.downstream_config, {
      name       = "downstream-${i}"
      local_name = "downstream-${i}.local.gd"
      }
    )
  ] : []

  tester_cluster = var.tester_cluster

  clusters = concat([local.upstream_cluster], local.downstream_clusters, [local.tester_cluster])

  // aws-specific
  first_local_kubernetes_api_port = 7445
  first_local_http_port           = 9080
  first_local_https_port          = 9443
  region                          = var.region
  availability_zone               = var.availability_zone
  ssh_private_key_path            = var.ssh_private_key_path // generate with `ssh-keygen -t ed25519`
  ssh_public_key_path             = var.ssh_public_key_path
}

variable "project_name" {
  type    = string
  default = "moio"
}

variable "region" {
  type    = string
  default = "us-east-2"
}

variable "availability_zone" {
  type    = string
  default = "us-east-2a"
}

variable "ssh_private_key_path" {
  type = string
}

variable "ssh_public_key_path" {
  type = string
}

variable "upstream_cluster" {
  type = object({
    name           = string
    server_count   = number
    agent_count    = number
    distro_version = string
    agent_labels   = optional(list(list(map(string))))
    agent_taints   = optional(list(list(map(string))))

    // aws-specific
    local_name    = string
    datastore     = optional(string)
    instance_type = string
    ami           = string
  })
  default = {
    name           = "upstream"
    server_count   = 3
    agent_count    = 2
    distro_version = "v1.24.12+k3s1"
    agent_labels = [
      [{ key : "monitoring", value : "true" }]
    ]
    agent_taints = [
      [{ key : "monitoring", value : "true", effect : "NoSchedule" }]
    ]

    // aws-specific
    local_name    = "upstream.local.gd"
    instance_type = "i3.large"
    ami           = "ami-009fd8a4732ea789b" // openSUSE-Leap-15-5-v20230608-hvm-ssd-x86_64
  }
}

variable "tester_cluster" {
  type = object({
    name           = string
    server_count   = number
    agent_count    = number
    distro_version = string
    agent_labels   = optional(list(list(map(string))), [])
    agent_taints   = optional(list(list(map(string))), [])

    // aws-specific
    local_name    = string
    instance_type = string
    ami           = string
  })
  default = {
    name           = "tester"
    server_count   = 1
    agent_count    = 0
    distro_version = "v1.24.12+k3s1"
    agent_labels   = []
    agent_taints   = []

    // aws-specific
    local_name    = "tester.local.gd"
    instance_type = "t3a.large"
    ami           = "ami-009fd8a4732ea789b" // openSUSE-Leap-15-5-v20230608-hvm-ssd-x86_64
  }
}

variable "num_downstreams" {
  type    = number
  default = 0
}

variable "downstream_config" {
  type = object({
    name           = optional(string)
    server_count   = number
    agent_count    = number
    distro_version = string
    agent_labels   = optional(list(list(map(string))), [])
    agent_taints   = optional(list(list(map(string))), [])

    // aws-specific
    local_name    = optional(string)
    instance_type = string
    ami           = string
  })
  default = {
    server_count   = 3
    agent_count    = 7
    distro_version = "v1.24.12+k3s1"

    // aws-specific
    instance_type = "t4g.large"
    ami           = "ami-0e55a8b472a265e3f" // openSUSE-Leap-15-5-v20230608-hvm-ssd-arm64
  }
}
