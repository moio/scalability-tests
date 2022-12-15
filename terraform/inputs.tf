variable "upstream_datastore" {
  type        = string
  description = "Use 'etcd' to deploy a dedicated etcd cluster, 'postgres' for a dedicated Postgres DB, null for embedded etcd"
}

variable "kine_executable" {
  type        = string
  description = "Path to an alternative kine executable or do not set for current kine version"
  default     = null
}

locals {
  region                      = "us-east-1"
  availability_zone           = "us-east-1a"
  secondary_availability_zone = "us-east-1b"

  bastion_ami = "ami-08ee40d4e354946c6" // amazon/suse-sles-15-sp4-v20221216-hvm-ssd-arm64

  postgres_ami           = "ami-0b5eea76982371e91" // Amazon Linux 2 AMI (HVM) - Kernel 5.10, SSD Volume Type
  postgres_instance_type = "m6id.4xlarge"

  etcd_ami           = "ami-0b5eea76982371e91" // Amazon Linux 2 AMI (HVM) - Kernel 5.10, SSD Volume Type
  etcd_instance_type = "m6id.4xlarge"
  etcd_server_count  = 3

  upstream_instance_type  = "t3a.xlarge"
  upstream_ami            = "ami-0ea1c7db66fee3098" // Ubuntu: us-east-1 jammy 22.04 LTS amd64 hvm:ebs-ssd 20230106
  upstream_server_count   = 3
  upstream_agent_count    = 0
  upstream_distro_version = "v1.24.6+k3s1"

  project_name         = "moio"
  ssh_private_key_path = "~/.ssh/id_ed25519"
  ssh_public_key_path  = "~/.ssh/id_ed25519.pub"
}
