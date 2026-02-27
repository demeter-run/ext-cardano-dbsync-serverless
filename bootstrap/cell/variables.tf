variable "namespace" {
  type = string
}

variable "salt" {
  type        = string
  description = "Salt used to identify all components as part of the cell. Should be unique between cells."
}

variable "certs_secret_name" {
  type    = string
  default = "pgbouncer-certs"
}

// PVC
variable "volume_name" {
  type = string
}

variable "storage_size" {
  type = string
}

variable "db_volume_claim" {
  type    = string
  default = null
}

variable "storage_class" {
  default = "nvme"
}

variable "access_mode" {
  default = "ReadWriteMany"
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

variable "postgres_size" {
  type = string
}

variable "postgres_tolerations" {
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
      operator = "Equal"
      value    = "disk-intensive"
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
      value    = "consistent"
  }]
}


variable "postgres_secret_name" {
  type = string
}

variable "postgres_config_name" {
  type    = string
  default = null
}

// PGBouncer
variable "pgbouncer_image_tag" {
  default = "1.21.0"
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
    salt                  = optional(string)
    network               = string
    dbsync_image          = optional(string)
    dbsync_image_tag      = string
    node_n2n_tcp_endpoint = string
    release               = string
    sync_status           = string
    replicas              = optional(number)
    enable_postgrest      = bool
    topology_zone         = optional(string)
    empty_args            = optional(bool, false)
    custom_config         = optional(bool, true)
    network_env_var       = optional(string, false)
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
