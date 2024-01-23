resource "kubernetes_config_map" "postgres_config" {
  metadata {
    namespace = var.namespace
    name      = var.postgres_config_name
  }

  data = {
    "postgresql.conf" = file("${path.module}/postgresql.conf")
  }
}

