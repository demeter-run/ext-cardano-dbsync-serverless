resource "kubernetes_deployment_v1" "postgrest" {
  count            = var.enable_postgrest == true ? 1 : 0
  wait_for_rollout = false

  metadata {
    namespace = var.namespace
    name      = "postgrest-${local.instance_name}"
    labels = {
      role    = "postgrest"
      network = var.network
      salt    = var.salt
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        role    = "postgrest"
        network = var.network
        salt    = var.salt
      }
    }

    template {
      metadata {
        labels = {
          role    = "postgrest"
          network = var.network
          salt    = var.salt
        }
      }

      spec {
        container {
          image = "postgrest/postgrest"
          name  = "main"

          env {
            name  = "PGRST_DB_URI"
            value = "postgres://"
          }

          env {
            name  = "PGRST_DB_SCHEMA"
            value = "public"
          }

          env {
            name  = "PGRST_DB_ANON_ROLE"
            value = "dmtrro"
          }

          env {
            name = "PGUSER"
            value_from {
              secret_key_ref {
                key  = "username"
                name = "postgres.${local.postgres_host}.credentials.postgresql.acid.zalan.do"
              }
            }
          }

          env {
            name = "PGPASSWORD"
            value_from {
              secret_key_ref {
                key  = "password"
                name = "postgres.${local.postgres_host}.credentials.postgresql.acid.zalan.do"
              }
            }
          }

          env {
            name  = "PGHOST"
            value = local.postgres_replica_service
          }

          env {
            name  = "PGPORT"
            value = "5432"
          }

          env {
            name  = "PGDATABASE"
            value = "cardanodbsync"
          }

          resources {
            limits = {
              memory = "500Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "50Mi"
            }
          }

          port {
            name           = "http"
            container_port = 3000
          }
        }
        toleration {
          effect   = "NoSchedule"
          key      = "demeter.run/compute-profile"
          operator = "Exists"
        }

        toleration {
          effect   = "NoSchedule"
          key      = "demeter.run/compute-arch"
          operator = "Exists"
        }

        toleration {
          effect   = "NoSchedule"
          key      = "demeter.run/availability-sla"
          operator = "Equal"
          value    = "consistent"
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "postgrest" {
  count = var.enable_postgrest == true ? 1 : 0

  metadata {
    namespace = var.namespace
    name      = "postgrest-${local.instance_name}"
  }
  spec {
    selector = {
      role    = "postgrest"
      network = var.network
      salt    = var.salt
    }

    port {
      name        = "http"
      port        = 3000
      target_port = 3000
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

