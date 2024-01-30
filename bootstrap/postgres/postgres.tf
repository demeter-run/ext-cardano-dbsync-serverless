resource "kubernetes_stateful_set_v1" "postgres" {
  wait_for_rollout = "false"
  metadata {
    name      = var.instance_name
    namespace = var.namespace
    labels = {
      "demeter.run/kind" = "DbsyncPostgres"
    }
  }
  spec {
    replicas     = 1
    service_name = "postgres"
    selector {
      match_labels = {
        "demeter.run/instance" = var.instance_name
      }
    }

    template {
      metadata {
        labels = {
          "demeter.run/instance" = var.instance_name
        }
      }
      spec {
        affinity {
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
        security_context {
          fs_group = 1000
        }

        container {
          name              = "main"
          image             = "postgres:${var.postgres_image_tag}"
          args              = ["-c", "config_file=/etc/postgresql/postgresql.conf"]
          image_pull_policy = "Always"

          port {
            container_port = 5432
            name           = "postgres"
            protocol       = "TCP"
          }

          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = var.postgres_secret_name
                key  = "password"
              }
            }
          }

          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/${var.namespace}/${var.instance_name}/pgdata"
          }

          resources {
            limits = {
              cpu    = var.postgres_resources.limits.cpu
              memory = var.postgres_resources.limits.memory
            }
            requests = {
              cpu    = var.postgres_resources.requests.cpu
              memory = var.postgres_resources.requests.memory
            }
          }

          volume_mount {
            mount_path = "/var/lib/postgresql/data"
            name       = "data"
          }

          volume_mount {
            mount_path = "/etc/postgresql/postgresql.conf"
            name       = "config"
            sub_path   = "postgresql.conf"
          }

          volume_mount {
            mount_path = "/dev/shm"
            name       = "dshm"
          }
        }

        container {
          name  = "exporter"
          image = "quay.io/prometheuscommunity/postgres-exporter:v0.12.0"
          env {
            name  = "DATA_SOURCE_URI"
            value = "localhost:5432/postgres?sslmode=disable"
          }
          env {
            name  = "DATA_SOURCE_USER"
            value = "postgres"
          }
          env {
            name = "DATA_SOURCE_PASS"
            value_from {
              secret_key_ref {
                name = var.postgres_secret_name
                key  = "password"
              }
            }
          }
          env {
            name  = "PG_EXPORTER_CONSTANT_LABELS"
            value = "service=dbsync-${var.instance_name}"
          }

          port {
            name           = "metrics"
            container_port = 9187
          }
        }

        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = var.db_volume_claim
          }
        }

        volume {
          name = "config"
          config_map {
            name = "postgres-config"
          }
        }

        volume {
          name = "dshm"
          empty_dir {
            medium     = "Memory"
            size_limit = "1Gi"
          }
        }

        toleration {
          effect   = "NoSchedule"
          key      = "demeter.run/compute-profile"
          operator = "Equal"
          value    = "disk-intensive"
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
          value    = "consistent"
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "postgres" {
  metadata {
    name      = var.instance_name
    namespace = var.namespace
    labels = {
      "demeter.run/kind" = "DbsyncPostgres"
    }
  }
  spec {
    selector = {
      "demeter.run/instance" = var.instance_name
    }
    type = "ClusterIP"
    port {
      port        = 5432
      target_port = 5432
      name        = "postgres"
    }
  }
}

