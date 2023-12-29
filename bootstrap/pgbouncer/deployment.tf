resource "kubernetes_deployment_v1" "dbsyncv2_pgcat" {
  wait_for_rollout = false
  metadata {
    labels = {
      role = "pgbouncer"
    }
    name      = "pgbouncer"
    namespace = var.namespace
  }

  spec {
    replicas = 2

    strategy {
      rolling_update {
        max_surge       = 1
        max_unavailable = 0
      }
    }

    selector {
      match_labels = {
        role = "pgbouncer"
      }
    }

    template {
      metadata {
        labels = {
          role = "pgbouncer"
        }
      }

      spec {
        container {
          name  = "main"
          image = "bitnami/pgbouncer:${var.image_tag}"

          resources {
            limits = {
              memory = "250Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "250Mi"
            }
          }

          port {
            container_port = 9930
            name           = "metrics"
            protocol       = "TCP"
          }

          port {
            container_port = 6432
            name           = "pgbouncer"
            protocol       = "TCP"
          }

          env {
            name  = "PGBOUNCER_DATABASE"
            value = "*"
          }

          env {
            name  = "POSTGRESQL_USERNAME"
            value = "postgres"
          }

          env {
            name = "POSTGRESQL_PASSWORD"
            value_from {
              secret_key_ref {
                name = "postgres.postgres-dbsync-v3"
                key  = "password"
              }
            }
          }

          env {
            name  = "POSTGRESQL_HOST"
            value = "postgres-dbsync-v3"
          }

          env {
            name  = "POSTGRESQL_PORT"
            value = "5432"
          }

          env {
            name  = "PGBOUNCER_DSN_0"
            value = "mainnet=host=postgres-dbsync-v3 port=5432 dbname=dbsync-mainnet auth_user=pgbouncer"
          }

          env {
            name  = "PGBOUNCER_DSN_1"
            value = "preview=host=postgres-dbsync-v3 port=5432 dbname=dbsync-preview auth_user=pgbouncer"
          }

          env {
            name  = "PGBOUNCER_DSN_2"
            value = "preprod=host=postgres-dbsync-v3 port=5432 dbname=dbsync-preprod auth_user=pgbouncer"
          }

          env {
            name = "PGBOUNCER_AUTH_USER"
            value = "pgbouncer"
          }

          env {
            name  = "PGBOUNCER_AUTH_QUERY"
            value = "SELECT usename, passwd FROM user_search($1)"
          }

          env {
            name  = "PGBOUNCER_IGNORE_STARTUP_PARAMETERS"
            value = "ignore_startup_parameters = extra_float_digits"
          }


          env {
            name = "PGBOUNCER_USERLIST_FILE"
            value = "/etc/pgbouncer/users.txt"
          }

          volume_mount {
            name       = "pgbouncer-config"
            mount_path = "/etc/pgbouncer"
          }

        }

        volume {
          name = "pgbouncer-config"
          config_map {
            name = "pgbouncer-config"
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
          operator = "Equal"
          value    = "x86"
        }

        toleration {
          effect   = "NoSchedule"
          key      = "demeter.run/availability-sla"
          operator = "Equal"
          value    = "best-effort"
        }
      }
    }
  }
}

resource "kubernetes_config_map" "dbsync_pgbouncer_config" {
  metadata {
    namespace = var.namespace
    name      = "pgbouncer-config"
  }

  data = {
    "users.txt" = "${file("${path.module}/users.txt")}"
  }
}
