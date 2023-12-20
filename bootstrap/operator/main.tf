variable "namespace" {}

variable "image_tag" {}

variable "per_min_dcus" {
  default = {
    "mainnet" : 84
    "default" : 53
  }
}

variable "scrape_interval" {
  description = "the inverval for polling workspaces data (in seconds)"
  default     = "30"
}

resource "kubernetes_cluster_role" "cluster-role" {
  metadata {
    name = "dbsync-operator"
  }

  rule {
    api_groups = ["", "demeter.run", "apps", "networking.k8s.io"]
    resources  = ["*"]
    verbs      = ["*"]
  }
}

resource "kubernetes_cluster_role_binding" "cluster-role-binding" {
  metadata {
    name = "dbsync-operator"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "dbsync-operator"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = var.namespace
  }
}

resource "kubernetes_deployment_v1" "deployment" {
  metadata {
    labels = {
      role = "operator"
    }
    name      = "operator"
    namespace = var.namespace
  }

  spec {
    replicas = 1

    strategy {
      rolling_update {
        max_surge       = 1
        max_unavailable = 0
      }
    }

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
          name = "main"

          image = "ghcr.io/demeter-run/cardano-dbsync-operator:${var.image_tag}"

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
            container_port = 9946
            name           = "metrics"
            protocol       = "TCP"
          }

          env {
            name  = "SHARED_PER_MIN_MAINNET_DCUS"
            value = var.per_min_dcus.mainnet
          }

          env {
            name  = "SHARED_PER_MIN_DEFAULT_DCUS"
            value = var.per_min_dcus.default
          }

          env {
            name  = "SCRAPE_INTERVAL_S"
            value = var.scrape_interval
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
