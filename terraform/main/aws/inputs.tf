locals {
  project_name         = "moio"
  region               = "us-east-1"
  availability_zone    = "us-east-1a"
  ssh_private_key_path = "~/.ssh/id_ed25519"   // generate with `ssh-keygen -t ed25519`
  ssh_public_key_path  = "~/.ssh/id_ed25519.pub"
}
