resource "kubernetes_namespace" "namespace" {
  metadata {
    name = var.namespace
  }
}

// Feature
module "dbsync_feature" {
  depends_on = [kubernetes_namespace.namespace]
  source     = "./feature"

  namespace            = var.namespace
  operator_image_tag   = var.operator_image_tag
  metrics_delay        = var.metrics_delay
  dcu_per_second       = var.dcu_per_second
  postgres_password    = var.postgres_password
  postgres_secret_name = var.postgres_secret_name
  pgbouncer_server_crt = var.pgbouncer_server_crt
  pgbouncer_server_key = var.pgbouncer_server_key

  postgres_hosts = coalesce(var.postgres_hosts, [for key in keys(var.cells) : "postgres-dbsync-v3-${key}"])
}

// Service
module "dbsync_service" {
  depends_on = [kubernetes_namespace.namespace]
  source     = "./service"

  namespace = var.namespace
}

// Cells
module "dbsync_cells" {
  depends_on = [module.dbsync_feature]
  for_each   = var.cells
  source     = "./cell"

  namespace = var.namespace
  salt      = each.key

  // PVC
  volume_name     = each.value.pvc.volume_name
  storage_size    = each.value.pvc.storage_size
  db_volume_claim = each.value.pvc.name

  // PG
  topology_zone        = each.value.postgres.topology_zone
  postgres_image_tag   = each.value.postgres.image_tag
  postgres_secret_name = var.postgres_secret_name
  postgres_resources   = each.value.postgres.resources
  postgres_config_name = each.value.postgres.config_name

  // PGBouncer
  pgbouncer_image_tag          = var.pgbouncer_image_tag
  pgbouncer_replicas           = each.value.pgbouncer.replicas
  pgbouncer_user_settings      = var.pgbouncer_user_settings
  pgbouncer_auth_user_password = var.pgbouncer_auth_user_password

  // Instances
  instances = each.value.instances
}
