terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

variable "namespace" {}


variable "dbsync_image" {
  type = string
  default = "ghcr.io/demeter-run/dbsync"
}
variable "dbsync_image_tag" {
  default = "132ffd0007054bfadd17b23ed608529447833b99"
}

variable "network" {}

variable "salt" {
  type = string
}

variable "topology_zone" {}

variable "node_n2n_tcp_endpoint" {
  type = string
}

variable "dbsync_resources" {
  type = object({
    requests = map(string)
    limits   = map(string)
  })

  default = {
    "limits" = {
      "memory" = "4Gi"
    }
    "requests" = {
      "memory" = "4Gi"
      "cpu"    = "100m"
    }
  }
}

variable "manual_dbsync_volume" {
  type    = bool
  default = false
}

variable "dbsync_volume" {
  type = object({
    storage_class = string
    size          = string
  })

  default = {
    manual        = false
    storage_class = "fast"
    size          = "10Gi"
  }
}

variable "enable_postgrest" {
  type    = bool
  default = false
}

variable "release" {
  type = string
}

variable "sync_status" {
  type = string
}

variable "postgres_instance_name" {
  type = string
}

variable "postgres_database" {
  type = string
}

variable "postgres_secret_name" {
  type = string
}

variable "compute_arch" {
  default = "arm64"
}

variable "compute_profile" {
  default = "mem-intensive"
}

variable "availability_sla" {
  default = "consistent"
}

variable "empty_args" {
  default = false
}

variable "custom_config" {
  default = true
}

variable "network_env_var" {
  default = false
}

module "configs" {
  source    = "../configs"
  network   = var.network
  namespace = var.namespace
  salt      = var.salt
}

locals {
  instance_name            = "${var.network}-${var.salt}"
  postgres_host            = "dmtr-postgres-${local.instance_name}"
  postgres_replica_service = "${local.postgres_host}-repl"
  config_map_name          = module.configs.cm_name
}
