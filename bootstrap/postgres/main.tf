variable "db_volume_claim" {
  type = string
}

variable "namespace" {
  type = string
}

variable "instance_name" {
  type = string
}

variable "topology_zone" {
  type = string
}

variable "postgres_image_tag" {
  type = string
}

variable "postgres_config_name" {
  default = "postgres-config"
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

variable "postgres_settings" {
  default = {
    listen_addresses                 = "*"
    max_connections                  = 1000
    shared_buffers                   = "8GB"
    effective_cache_size             = "24GB"
    maintenance_work_mem             = "2GB"
    checkpoint_completion_target     = 0.9
    wal_buffers                      = "16MB"
    default_statistics_target        = 500
    random_page_cost                 = 1.1
    effective_io_concurrency         = 200
    work_mem                         = "1048kB"
    huge_pages                       = "try"
    min_wal_size                     = "4GB"
    max_wal_size                     = "16GB"
    max_worker_processes             = 8
    max_parallel_workers_per_gather  = 4
    max_parallel_workers             = 8
    max_parallel_maintenance_workers = 4
    ssl                              = "off"
  }
}

variable "pg_bouncer_image_tag" {
  default = "1.21.0"
}

variable "dbsync_probe_image_tag" {
  default = "9a41a8e9d9cba3b4439d2a30b13f029fd63c0321"
}

variable "pg_bouncer_replicas" {
  default = 1
}