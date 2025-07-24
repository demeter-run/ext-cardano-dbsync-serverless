resource "kubernetes_persistent_volume_claim" "state" {
  count = var.manual_dbsync_volume == true ? 0 : 1

  wait_until_bound = false

  metadata {
    name      = "state-${local.instance_name}"
    namespace = var.namespace
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.dbsync_volume.storage_class

    resources {
      requests = {
        storage = var.dbsync_volume.size
      }
    }
  }
}

resource "kubernetes_deployment_v1" "db_sync" {
  wait_for_rollout = false
  metadata {
    labels = {
      salt    = var.salt
      network = var.network
      role    = "dbsync"
    }
    name      = "${local.instance_name}-dbsync"
    namespace = var.namespace
  }

  spec {
    replicas = var.replicas

    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = {
        salt    = var.salt
        network = var.network
        role    = "dbsync"
      }
    }

    template {
      metadata {
        labels = {
          salt    = var.salt
          network = var.network
          role    = "dbsync"
        }
      }

      spec {
        dynamic "affinity" {
          for_each = var.topology_zone != null ? toset([1]) : toset([])

          content {
            node_affinity {
              required_during_scheduling_ignored_during_execution {
                node_selector_term {
                  match_expressions {
                    key      = "topology.kubernetes.io/zone"
                    operator = "In"
                    values   = [var.topology_zone]
                  }
                }
              }
            }
          }
        }

        dynamic "init_container" {
          for_each = var.network == "vector-testnet" ? toset([1]) : toset([])

          content {
            name = "init-pgpass"

            image = "busybox"

            command = [
              "sh", "-c", <<-EOT
              echo "$(echo $POSTGRES_HOST):$(echo $POSTGRES_PORT):$(echo $POSTGRES_DB):$(echo $POSTGRES_USER):$(echo $POSTGRES_PASSWORD)" > /etc/pgpass/pgpass
              chmod 600 /etc/pgpass/pgpass
              EOT
            ]
            env {
              name  = "POSTGRES_USER"
              value = "postgres"
            }

            env {
              name = "POSTGRES_PASSWORD"
              value_from {
                secret_key_ref {
                  key  = "password"
                  name = var.postgres_secret_name
                }
              }
            }

            env {
              name  = "POSTGRES_DB"
              value = var.postgres_database
            }

            env {
              name  = "POSTGRES_HOST"
              value = var.postgres_instance_name
            }

            env {
              name  = "POSTGRES_PORT"
              value = "5432"
            }
            volume_mount {
              name       = "pgpass-volume"
              mount_path = "/etc/pgpass"
            }
          }
        }

        container {
          args = [
            "-d",
            "UNIX-LISTEN:/node-ipc/node.socket,fork,reuseaddr,unlink-early",
            "TCP:${var.node_n2n_tcp_endpoint}",
          ]

          image = "alpine/socat:latest"

          name = "socat"

          volume_mount {
            mount_path = "/node-ipc"
            name       = "cardanoipc"
          }
        }

        container {
          name = "dbsync"

          image = "${var.dbsync_image}:${var.dbsync_image_tag}"

          resources {
            limits   = var.dbsync_resources.limits
            requests = var.dbsync_resources.requests
          }

          args = var.empty_args ? [] : [
            "--config /etc/dbsync/db-sync-config.json",
            "--socket-path /node-ipc/node.socket",
          ]

          env {
            name  = "POSTGRES_USER"
            value = "postgres"
          }

          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                key  = "password"
                name = var.postgres_secret_name
              }
            }
          }

          env {
            name  = "POSTGRES_DB"
            value = var.postgres_database
          }

          env {
            name  = "POSTGRES_HOST"
            value = var.postgres_instance_name
          }

          env {
            name  = "POSTGRES_PORT"
            value = "5432"
          }

          env {
            name  = "RESTORE_RECREATE"
            value = "N"
          }

          env {
            name  = "NETWORK"
            value = var.network_env_var ? var.network : ""
          }

          dynamic "env" {
            for_each = var.network == "vector-testnet" ? toset([1]) : toset([])
            content {
              name  = "PGPASSFILE"
              value = "/etc/pgpass/pgpass"
            }
          }

          dynamic "volume_mount" {
            for_each = var.custom_config ? toset([1]) : toset([])
            content {
              name       = "config"
              mount_path = "/etc/dbsync"
            }
          }

          volume_mount {
            mount_path = "/node-ipc"
            name       = "cardanoipc"
          }

          volume_mount {
            mount_path = "/var/lib/cexplorer"
            name       = "state"
          }

          dynamic "volume_mount" {
            for_each = var.network == "vector-testnet" ? toset([1]) : toset([])
            content {
              name       = "pgpass-volume"
              mount_path = "/etc/pgpass"
            }
          }

          port {
            container_port = 8080
            name           = "metrics"
          }
        }
        dynamic "volume" {
          for_each = var.custom_config ? toset([1]) : toset([0])
          content {
            name = "config"
            config_map {
              name = local.config_map_name
            }
          }
        }

        volume {
          name = "cardanoipc"
          empty_dir {}
        }

        volume {
          name = "state"
          persistent_volume_claim {
            claim_name = "state-${local.instance_name}"
          }
        }

        dynamic "volume" {
          for_each = var.network == "vector-testnet" ? toset([1]) : toset([])
          content {
            name = "pgpass-volume"
            empty_dir {}
          }
        }

        dynamic "toleration" {
          for_each = var.tolerations

          content {
            effect   = toleration.value.effect
            key      = toleration.value.key
            operator = toleration.value.operator
            value    = toleration.value.value
          }
        }
      }
    }
  }
}
