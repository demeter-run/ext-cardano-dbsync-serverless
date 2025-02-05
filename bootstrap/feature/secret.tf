resource "kubernetes_secret" "postgres" {
  metadata {
    name      = var.postgres_secret_name
    namespace = var.namespace
  }
  data = {
    "password" = var.postgres_password
  }
  type = "Opaque"
}

resource "kubernetes_secret" "pgbouncer_certs" {
  metadata {
    namespace = var.namespace
    name      = "pgbouncer-certs"
  }

  data = {
    "tls.crt" = var.pgbouncer_server_crt
    "tls.key" = var.pgbouncer_server_key
  }
}
