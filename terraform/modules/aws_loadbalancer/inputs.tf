variable "subdomain" {
  type = string
}

variable "domain" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnets" {
  type = list(string)
}

variable "use_route53" {
  type    = bool
  default = false
}

