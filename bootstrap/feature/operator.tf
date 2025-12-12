locals {
  postgres_urls          = [for host in var.postgres_hosts : "postgres://postgres:$(POSTGRES_PASSWORD)@${host}:5432"]
  combined_postgres_urls = join(",", local.postgres_urls)
}

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
          image = "ghcr.io/demeter-run/ext-cardano-dbsync-serverless:${var.operator_image_tag}"
          name  = "main"

          env {
            name  = "K8S_IN_CLUSTER"
            value = "true"
          }

          env {
            name  = "METRICS_DELAY"
            value = var.metrics_delay
          }

          env {
            name  = "ADDR"
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
            name  = "DB_URLS"
            value = local.combined_postgres_urls
          }

          env {
            name  = "DB_NAMES"
            value = "vector-testnet=dbsync-vector-testnet,prime-testnet=dbsync-prime-testnet,cardano-mainnet=dbsync-mainnet,cardano-preprod=dbsync-preprod,cardano-preview=dbsync-preview"
          }

          env {
            name  = "PROMETHEUS_URL"
            value = "http://prometheus-operated.demeter-system.svc.cluster.local:9090/api/v1"
          }

          env {
            name  = "RUST_BACKTRACE"
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

