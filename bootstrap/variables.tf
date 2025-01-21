variable "namespace" {
  type = string
}

variable "cloud_provider" {
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

variable "pgbouncer_reloader_image_tag" {
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

variable "pgbouncer_auth_user_password" {
  type = string
}

variable "cells" {
  type = map(object({
    pvc = object({
      volume_name        = optional(string)
      storage_size       = string
      storage_class_name = string
      access_mode        = string
      name               = optional(string)
    })
    postgres = object({
      image_tag             = string
      topology_zone         = string
      is_blockfrost_backend = bool
      config_name           = optional(string)
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
      tolerations = optional(list(object({
        key      = string
        operator = string
        value    = string
        effect   = string
      })))
    })
    pgbouncer = object({
      replicas           = number
      reloader_image_tag = optional(string)
      auth_user_password = optional(string)
      load_balancer      = optional(bool, false)
      certs_secret_name  = optional(string, "pgbouncer-certs")
      tolerations = optional(list(object({
        key      = string
        operator = string
        value    = string
        effect   = string
      })))
    })
    instances = map(object({
      salt                  = optional(string)
      network               = string
      dbsync_image          = optional(string)
      dbsync_image_tag      = string
      node_n2n_tcp_endpoint = string
      release               = string
      sync_status           = string
      enable_postgrest      = bool
      empty_args            = optional(bool, false)
      custom_config         = optional(bool, true)
      network_env_var       = optional(string, false)
      topology_zone         = optional(string)
      dbsync_resources = optional(object({
        requests = map(string)
        limits   = map(string)
      }))
      dbsync_volume = optional(object({
        storage_class = string
        size          = string
      }))
      tolerations = optional(list(object({
        effect   = string
        key      = string
        operator = string
        value    = optional(string)
      })))
    }))
  }))
}
