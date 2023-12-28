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


variable "operator_image_tag" {
  type = string
}

variable "metrics_delay" {
  default = 30
}

variable "dcu_per_second" {
  type = map(string)
  default = {
    "mainnet" = "10"
    "preprod" = "5"
    "preview" = "5"
  }
}

variable "postgres_host" {
  type = string
}

variable "postgres_secret_name" {
  type = string
}