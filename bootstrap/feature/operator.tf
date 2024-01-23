resource "kubernetes_deployment_v1" "operator" {
  wait_for_rollout = false

  metadata {
    namespace = var.namespace
    name      = "operator"
    labels = {
      role = "operator"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        role = "operator"
      }
    }

    template {
      metadata {
        labels = {
          role = "operator"
        }
      }

      spec {
        container {
          image   = "ghcr.io/demeter-run/ext-cardano-dbsync-serverless:${var.operator_image_tag}"
          name    = "main"

          env {
            name  = "K8S_IN_CLUSTER"
            value = "true"
          }

          env {
            name  = "METRICS_DELAY"
            value = var.metrics_delay
          }

          env {
            name = "ADDR"
            value = "0.0.0.0:5000"
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
            name = "DCU_PER_SECOND"
            value = "mainnet=${var.dcu_per_second["mainnet"]},preprod=${var.dcu_per_second["preprod"]},preview=${var.dcu_per_second["preview"]}"
          }

          env {
            name = "DB_URLS"
            value = "postgres://postgres:$(POSTGRES_PASSWORD)@${var.postgres_host_1}:5432,postgres://postgres:$(POSTGRES_PASSWORD)@${var.postgres_host_2}:5432"
          }

          env {
            name = "DB_NAMES"
            value = "mainnet=dbsync-mainnet,preprod=dbsync-preprod,preview=dbsync-preview"
          }

          env {
            name = "RUST_BACKTRACE"
            value = "1"
          }

         
          resources {
            limits = {
              memory = "256Mi"
            }
            requests = {
              cpu    = "50m"
              memory = "256Mi"
            }
          }

          port {
            name           = "metrics"
            container_port = 5000
            protocol       = "TCP"
          }
        }

        toleration {
          effect   = "NoSchedule"
          key      = "demeter.run/compute-profile"
          operator = "Equal"
          value    = "general-purpose"
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

