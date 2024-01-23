resource "kubernetes_secret" "postgres" {
  metadata {
    name      = "${var.postgres_secret_name}"
    namespace = var.namespace
  }
  data = {
    "password" = var.postgres_password
  }
  type = "Opaque"
}
