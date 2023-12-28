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
    replicas = 1

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

          image = "ghcr.io/demeter-run/dbsync:${var.dbsync_image_tag}"

          resources {
            limits   = var.dbsync_resources.limits
            requests = var.dbsync_resources.requests
          }

          args = [
            "--config /etc/dbsync/db-sync-config.json",
            "--socket-path /node-ipc/node.socket"
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
                name = "postgres.${var.postgres_instance_name}"
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
            name = "NETWORK"
            value = ""
          }

          volume_mount {
            mount_path = "/etc/dbsync"
            name       = "config"
          }

          volume_mount {
            mount_path = "/node-ipc"
            name       = "cardanoipc"
          }

          volume_mount {
            mount_path = "/var/lib/cexplorer"
            name       = "state"
          }

          port {
            container_port = 8080
            name           = "metrics"
          }
        }

        volume {
          name = "config"
          config_map {
            name = local.config_map_name
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

        toleration {
          key      = "demeter.run/workload"
          operator = "Equal"
          value    = "mem-intensive"
          effect   = "NoSchedule"
        }

        toleration {
          effect   = "NoSchedule"
          key      = "demeter.run/compute-profile"
          operator = "Equal"
          value    = "mem-intensive"
        }

        toleration {
          effect   = "NoSchedule"
          key      = "demeter.run/compute-arch"
          operator = "Equal"
          value    = "arm64"
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
