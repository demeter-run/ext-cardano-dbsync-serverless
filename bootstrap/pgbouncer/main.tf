variable "namespace" {
  type = string
}

variable "instance_name" {
  default = "dbsync-v3-pgbouncer"
}

variable "service_name" {
  default = "dbsync-v3-pgbouncer"
}

variable "pg_bouncer_image_tag" {
  default = "1.21.0"
}

variable "dbsync_probe_image_tag" {
  default = "27a9dbc30253e7d2036f1d6648d406f3d17a90e2"
}

variable "dns_zone" {
  default = "demeter.run"
}

variable "extension_name" {
  default = "dbsync-v3"
}

variable "instance_role" {
  default = "pgbouncer"
}

variable "cluster_issuer" {
  type    = string
  default = "letsencrypt-dns01"
}

variable "pg_bouncer_replicas" {
  default = 1
}

variable "certs_secret_name" {
  type    = string
  default = "pgbouncer-certs"
}

variable "pgbouncer_reloader_image_tag" {
  type = string
}

variable "pg_bouncer_auth_user_password" {
  type    = string
  default = ""
}

variable "postgres_secret_name" {
  type    = string
  default = ""
}

variable "postgres_instance_name" {
  type    = string
  default = "postgres-dbsync-v3-ar9"
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
