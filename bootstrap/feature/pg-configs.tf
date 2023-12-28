resource "kubernetes_config_map" "postgres_config" {
  metadata {
    namespace = var.namespace
    name      = "postgres-config"
  }

  data = {
    "postgresql.conf" = file("${path.module}/postgresql.conf")
  }
}
