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

variable "is_blockfrost_backend" {
  type = bool
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
    max_connections                  = 101
    shared_buffers                   = "12GB"
    effective_cache_size             = "36GB"
    maintenance_work_mem             = "2GB"
    checkpoint_completion_target     = 0.9
    wal_buffers                      = "16MB"
    default_statistics_target        = 500
    random_page_cost                 = 1.1
    effective_io_concurrency         = 200
    work_mem                         = "15728kB"
    huge_pages                       = "try"
    min_wal_size                     = "4GB"
    max_wal_size                     = "16GB"
    max_worker_processes             = 8
    max_parallel_workers_per_gather  = 4
    max_parallel_workers             = 8
    max_parallel_maintenance_workers = 4
    ssl                              = "off"
    shared_preload_libraries         = "pg_stat_statements"
    max_pred_locks_per_transaction   = 256
  }
}

