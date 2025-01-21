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
  depends_on     = [kubernetes_namespace.namespace]
  source         = "./service"
  cloud_provider = var.cloud_provider
  namespace      = var.namespace
}

// Cells
module "dbsync_cells" {
  depends_on = [module.dbsync_feature]
  for_each   = var.cells
  source     = "./cell"

  namespace = var.namespace
  salt      = each.key

  // PVC
  access_mode        = each.value.pvc.access_mode
  db_volume_claim    = each.value.pvc.name
  storage_class_name = each.value.pvc.storage_class_name
  storage_size       = each.value.pvc.storage_size
  volume_name        = each.value.pvc.volume_name

  // PG
  topology_zone         = each.value.postgres.topology_zone
  is_blockfrost_backend = each.value.postgres.is_blockfrost_backend
  postgres_image_tag    = each.value.postgres.image_tag
  postgres_secret_name  = var.postgres_secret_name
  postgres_resources    = each.value.postgres.resources
  postgres_config_name  = each.value.postgres.config_name
  postgres_tolerations  = each.value.postgres.tolerations

  // PGBouncer
  certs_secret_name            = each.value.pgbouncer.certs_secret_name
  pgbouncer_cloud_provider     = var.cloud_provider
  pgbouncer_image_tag          = var.pgbouncer_image_tag
  pgbouncer_load_balancer      = each.value.pgbouncer.load_balancer
  pgbouncer_replicas           = each.value.pgbouncer.replicas
  pgbouncer_auth_user_password = var.pgbouncer_auth_user_password
  pgbouncer_reloader_image_tag = var.pgbouncer_reloader_image_tag
  pgbouncer_tolerations        = each.value.pgbouncer.tolerations

  // Instances
  instances = each.value.instances
}
