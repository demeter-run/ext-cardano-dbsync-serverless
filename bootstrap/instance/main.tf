terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
  }
}

variable "namespace" {}

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

variable "postgres_resources" {
  type = object({
    requests = map(string)
    limits   = map(string)
  })

  default = {
    "limits" = {
      memory = "2Gi"
      cpu    = "4000m"
    }
    "requests" = {
      memory = "2Gi"
      cpu    = "100m"
    }
  }
}

variable "postgres_params" {
  default = {
    "max_standby_archive_delay"   = "900s"
    "max_standby_streaming_delay" = "900s"
  }
}

variable "postgres_volume" {
  type = object({
    storage_class = string
    size          = string
  })

  default = {
    storage_class = "fast"
    size          = "30Gi"
  }
}

variable "postgres_replicas" {
  type    = number
  default = 2
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

variable "enable_master_load_balancer" {
  type    = bool
  default = false
}

variable "enable_replica_load_balancer" {
  type    = bool
  default = false
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
  users_job_name           = "setusers-${local.instance_name}"
  secrets_name             = "${local.postgres_host}.credentials.postgresql.acid.zalan.do"
  config_map_name          = module.configs.cm_name
}
