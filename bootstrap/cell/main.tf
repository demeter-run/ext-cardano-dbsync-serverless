// Each cell of the dbsync extension containes 1 PVC, 1 Postgres instance, 1
// PGBouncer that acts proxy and an amount of instances (commonly 3, one per
// network).
locals {
  postgres_host        = "postgres-dbsync-v3-${var.salt}"
  dbsync_image         = "ghcr.io/demeter-run/dbsync"
  db_volume_claim      = coalesce(var.db_volume_claim, "pvc-${var.salt}")
  postgres_config_name = coalesce(var.postgres_config_name, "postgres-config-${var.salt}")
  default_tolerations = [
    {
      effect   = "NoSchedule"
      key      = "demeter.run/workload"
      operator = "Equal"
      value    = "mem-intensive"
    },
    {
      effect   = "NoSchedule"
      key      = "demeter.run/compute-profile"
      operator = "Equal"
      value    = "mem-intensive"
    },
    {
      effect   = "NoSchedule"
      key      = "demeter.run/compute-arch"
      operator = "Equal"
      value    = "arm64"
    },
    {
      effect   = "NoSchedule"
      key      = "demeter.run/availability-sla"
      operator = "Equal"
      value    = "consistent"
    }
  ]
}
module "dbsync_pvc" {
  source       = "../pvc"
  namespace    = var.namespace
  volume_name  = var.volume_name
  storage_size = var.storage_size
  name         = local.db_volume_claim
}

module "dbsync_postgres" {
  source = "../postgres"

  namespace             = var.namespace
  db_volume_claim       = local.db_volume_claim
  instance_name         = local.postgres_host
  postgres_config_name  = local.postgres_config_name
  topology_zone         = var.topology_zone
  postgres_image_tag    = var.postgres_image_tag
  postgres_secret_name  = var.postgres_secret_name
  postgres_resources    = var.postgres_resources
  is_blockfrost_backend = var.is_blockfrost_backend
}

module "dbsync_pgbouncer" {
  source = "../pgbouncer"

  namespace                     = var.namespace
  pg_bouncer_replicas           = var.pgbouncer_replicas
  certs_secret_name             = var.certs_secret_name
  pg_bouncer_auth_user_password = var.pgbouncer_auth_user_password
  instance_role                 = "pgbouncer"
  postgres_secret_name          = var.postgres_secret_name
  instance_name                 = "postgres-dbsync-v3-${var.salt}"
  postgres_instance_name        = local.postgres_host
  pgbouncer_reloader_image_tag  = var.pgbouncer_reloader_image_tag
}

module "dbsync_instances" {
  source   = "../instance"
  for_each = var.instances

  namespace              = var.namespace
  network                = each.value.network
  salt                   = coalesce(each.value.salt, var.salt)
  dbsync_image           = coalesce(each.value.dbsync_image, local.dbsync_image)
  dbsync_image_tag       = each.value.dbsync_image_tag
  node_n2n_tcp_endpoint  = each.value.node_n2n_tcp_endpoint
  release                = each.value.release
  replicas               = coalesce(each.value.replicas, 1)
  topology_zone          = coalesce(each.value.topology_zone, var.topology_zone)
  sync_status            = each.value.sync_status
  empty_args             = coalesce(each.value.empty_args, false)
  custom_config          = coalesce(each.value.custom_config, true)
  network_env_var        = coalesce(each.value.network_env_var, false)
  enable_postgrest       = each.value.enable_postgrest
  postgres_database      = "dbsync-${each.value.network}"
  postgres_instance_name = local.postgres_host
  postgres_secret_name   = var.postgres_secret_name

  dbsync_resources = coalesce(each.value.dbsync_resources, {
    "limits" = {
      "memory" = "4Gi"
    }
    "requests" = {
      "memory" = "4Gi"
      "cpu"    = "100m"
    }
  })
  dbsync_volume = coalesce(each.value.dbsync_volume, {
    manual        = false
    storage_class = "fast"
    size          = "10Gi"
  })
  tolerations = coalesce(each.value.tolerations, local.default_tolerations)
}
