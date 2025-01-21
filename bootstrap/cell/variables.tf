variable "namespace" {
  type = string
}

variable "salt" {
  type        = string
  description = "Salt used to identify all components as part of the cell. Should be unique between cells."
}

// PVC
variable "volume_name" {
  type = string
}

variable "storage_size" {
  type = string
}

variable "storage_class_name" {
  type = string
}

variable "access_mode" {
  type = string
}

variable "db_volume_claim" {
  type    = string
  default = null
}

// Postgres
variable "topology_zone" {
  type = string
}

variable "is_blockfrost_backend" {
  type = bool
}

variable "postgres_image_tag" {
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

variable "postgres_secret_name" {
  type = string
}

variable "postgres_config_name" {
  type    = string
  default = null
}

variable "postgres_tolerations" {
  type = list(object({
    key      = string
    operator = string
    value    = string
    effect   = string
  }))
  default = [
    {
      key      = "demeter.run/compute-profile"
      operator = "Equal"
      value    = "disk-intensive"
      effect   = "NoSchedule"
    },
    {
      key      = "demeter.run/compute-arch"
      operator = "Equal"
      value    = "x86"
      effect   = "NoSchedule"
    },
    {
      key      = "demeter.run/availability-sla"
      operator = "Equal"
      value    = "consistent"
      effect   = "NoSchedule"
    }
  ]
}

// PGBouncer

variable "certs_secret_name" {
  type    = string
  default = "pgbouncer-certs"
}

variable "pgbouncer_cloud_provider" {
  type = string
}

variable "pgbouncer_image_tag" {
  default = "1.21.0"
}

variable "pgbouncer_load_balancer" {
  type = bool
}

variable "pgbouncer_replicas" {
  default = 1
}

variable "pgbouncer_auth_user_password" {
  type = string
}

variable "pgbouncer_reloader_image_tag" {
  type = string
}

variable "pgbouncer_tolerations" {
  type = list(object({
    effect   = string
    key      = string
    operator = string
    value    = optional(string)
  }))
  default = [
    {
      effect   = "NoSchedule"
      key      = "demeter.run/compute-profile"
      operator = "Exists"
    },
    {
      effect   = "NoSchedule"
      key      = "demeter.run/compute-arch"
      operator = "Equal"
      value    = "x86"
    },
    {
      effect   = "NoSchedule"
      key      = "demeter.run/availability-sla"
      operator = "Equal"
      value    = "best-effort"
    }
  ]
}

// Instance
variable "instances" {
  type = map(object({
    salt                   = optional(string)
    network                = string
    dbsync_image           = optional(string)
    dbsync_image_tag       = string
    node_n2n_tcp_endpoint  = string
    release                = string
    sync_status            = string
    enable_postgrest       = bool
    args                   = optional(list(string), [])
    custom_config          = optional(bool, true)
    topology_zone          = optional(string)
    postgres_instance_name = optional(string)
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
}

variable "enable_postgres" {
  type    = bool
  default = true
}

variable "enable_pgbouncer" {
  type    = bool
  default = true
}
