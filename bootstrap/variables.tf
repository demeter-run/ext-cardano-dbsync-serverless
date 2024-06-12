variable "namespace" {
  type = string
}

// Feature
variable "operator_image_tag" {
  type = string
}

variable "metrics_delay" {
  type    = number
  default = 60
}

variable "dcu_per_second" {
  type = map(string)
  default = {
    "mainnet"   = "10"
    "preprod"   = "5"
    "preview"   = "5"
    "sanchonet" = "5"
  }
}

variable "postgres_secret_name" {
  type    = string
  default = "postgres-secret"
}

variable "postgres_password" {
  type = string
}

variable "pgbouncer_server_crt" {
  type = string
}

variable "pgbouncer_server_key" {
  type = string
}

variable "postgres_hosts" {
  type    = list(string)
  default = null
}

variable "operator_resources" {
  type = object({
    limits = object({
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    limits = {
      cpu    = "1"
      memory = "512Mi"
    }
    requests = {
      cpu    = "50m"
      memory = "512Mi"
    }
  }
}

// PGBouncer
variable "pgbouncer_image_tag" {
  type    = string
  default = "1.21.0"
}

variable "pgbouncer_user_settings" {
  default = []
  type = list(object({
    name            = string
    password        = string
    max_connections = number
  }))
}

variable "pgbouncer_auth_user_password" {
  type = string
}

variable "cells" {
  type = map(object({
    pvc = object({
      volume_name  = string
      storage_size = string
      name         = string
    })
    postgres = object({
      image_tag     = string
      topology_zone = string
      config_name   = optional(string)
      resources = object({
        limits = object({
          cpu    = string
          memory = string
        })
        requests = object({
          cpu    = string
          memory = string
        })
      })
    })
    pgbouncer = object({
      replicas = number
    })
    instances = map(object({
      salt                  = optional(string)
      network               = string
      dbsync_image_tag      = string
      node_n2n_tcp_endpoint = string
      release               = string
      sync_status           = string
      enable_postgrest      = bool
      topology_zone         = optional(string)
      dbsync_resources = optional(object({
        requests = map(string)
        limits   = map(string)
      }))
      dbsync_volume = optional(object({
        storage_class = string
        size          = string
      }))
    }))
  }))
}
