resource "kubernetes_config_map" "pgbouncer_certs" {
  metadata {
    namespace = var.namespace
    name      = "pgbouncer-certs"
  }

  data = {
    "server.crt" = var.pgbouncer_server_crt
    "server.key" = var.pgbouncer_server_key
  }
}
