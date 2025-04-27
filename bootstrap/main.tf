resource "kubernetes_namespace" "namespace" {
  for_each = var.create_namespace ? { "enabled" = true } : {}
  metadata {
    name = var.namespace
  }
}

// Feature
module "dbsync_feature" {
  depends_on = [kubernetes_namespace.namespace]
  source     = "./feature"
  for_each   = var.enable_postgres ? { "enabled" = true } : {}

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

  namespace        = var.namespace
  salt             = each.key
  enable_postgres  = var.enable_postgres
  enable_pgbouncer = var.enable_pgbouncer

  // PVC
  access_mode        = each.value.pvc.access_mode
  db_volume_claim    = each.value.pvc.name
  storage_class_name = each.value.pvc.storage_class_name
  storage_size       = each.value.pvc.storage_size
  volume_name        = each.value.pvc.volume_name

  // PG: conditionally defined if each cell has a postgres key
  topology_zone         = each.value.postgres != null ? each.value.postgres.topology_zone : null
  is_blockfrost_backend = each.value.postgres != null ? each.value.postgres.is_blockfrost_backend : null
  postgres_image_tag    = each.value.postgres != null ? each.value.postgres.image_tag : null
  postgres_secret_name  = each.value.postgres != null ? var.postgres_secret_name : null
  postgres_resources    = each.value.postgres != null ? each.value.postgres.resources : null
  postgres_config_name  = each.value.postgres != null ? each.value.postgres.config_name : null
  postgres_tolerations  = each.value.postgres != null ? each.value.postgres.tolerations : null

  // PGBouncer: conditionally defined if each cell has a pgbouncer key
  certs_secret_name            = each.value.pgbouncer != null ? each.value.pgbouncer.certs_secret_name : null
  pgbouncer_cloud_provider     = each.value.pgbouncer != null ? var.cloud_provider : null
  pgbouncer_image_tag          = each.value.pgbouncer != null ? var.pgbouncer_image_tag : null
  pgbouncer_load_balancer      = each.value.pgbouncer != null ? each.value.pgbouncer.load_balancer : null
  pgbouncer_replicas           = each.value.pgbouncer != null ? each.value.pgbouncer.replicas : null
  pgbouncer_auth_user_password = each.value.pgbouncer != null ? var.pgbouncer_auth_user_password : null
  pgbouncer_reloader_image_tag = each.value.pgbouncer != null ? var.pgbouncer_reloader_image_tag : null
  pgbouncer_tolerations        = each.value.pgbouncer != null ? each.value.pgbouncer.tolerations : null

  // Instances
  instances = each.value.instances
}
