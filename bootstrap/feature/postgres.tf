locals {
  node_affinity = {
    "requiredDuringSchedulingIgnoredDuringExecution" = {
      "nodeSelectorTerms" = [
        {
          "matchExpressions" = [
            {
              "key"      = "topology.kubernetes.io/zone"
              "operator" = "In"
              "values"   = [var.topology_zone]
            }
          ]
        }
      ]
    }
  }
}

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
        security_context {
          fs_group = 1000
        }

        container {
          name              = "main"
          image             = "postgres:${var.image_tag}"
          image_pull_policy = "Always"

          port {
            container_port = 1442
            name           = "http"
            protocol       = "TCP"
          }

          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = "postgres-${var.instance_name}"
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
              cpu    = var.resources.limits.cpu
              memory = var.resources.limits.memory
            }
            requests = {
              cpu    = var.resources.requests.cpu
              memory = var.resources.requests.memory
            }
          }

          volume_mount {
            mount_path = "/var/lib/postgresql/data"
            name       = "data"
          }

        }

        container {
          name  = "exporter"
          image = "quay.io/prometheuscommunity/postgres-exporter:v0.12.0"
          env {
            name  = "DATA_SOURCE_URI"
            value = "localhost:5432/dbsync-mainnet?sslmode=disable,localhost:5432/dbsync-preview?sslmode=disable,localhost:5432/dbsync-preprod?sslmode=disable"
          }
          env {
            name  = "DATA_SOURCE_USER"
            value = "$(POSTGRES_USER)"
          }
          env {
            name  = "DATA_SOURCE_PASS"
            value = "$(POSTGRES_PASSWORD)"
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



# resource "kubernetes_manifest" "postgres" {
#   field_manager {
#     force_conflicts = true
#   }
#   manifest = {
#     "apiVersion" = "acid.zalan.do/v1"
#     "kind"       = "postgresql"
#     "metadata" = {
#       "name"      = local.postgres_host
#       "namespace" = var.namespace
#       "labels" = {
#         "dbsync-status" = "ready"
#       }
#     }
#     "spec" = {
#       "env" : [
#         {
#           "name" : "ALLOW_NOSSL"
#           "value" : "true"
#         }
#       ]
#       "numberOfInstances"         = var.postgres_replicas
#       "enableMasterLoadBalancer"  = var.enable_master_load_balancer
#       "enableReplicaLoadBalancer" = var.enable_replica_load_balancer
#       "allowedSourceRanges" = [
#         "0.0.0.0/0"
#       ]
#       "dockerImage" : "ghcr.io/zalando/spilo-15:3.0-p1"
#       "teamId" = "dmtr"
#       "tolerations" = [
#         {
#           "effect"   = "NoSchedule"
#           "key"      = "demeter.run/compute-profile"
#           "operator" = "Equal"
#           "value"    = "disk-intesive"
#         },
#         {
#           "effect"   = "NoSchedule"
#           "key"      = "demeter.run/compute-arch"
#           "operator" = "Equal"
#           "value"    = "x86"
#         },
#         {
#           "effect"   = "NoSchedule"
#           "key"      = "demeter.run/availability-sla"
#           "operator" = "Equal"
#           "value"    = "consistent"
#         }
#       ]
#       "nodeAffinity" = var.topology_zone != null ? local.node_affinity : null
#       "serviceAnnotations" : {
#         "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "instance"
#         "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"
#         "service.beta.kubernetes.io/aws-load-balancer-type"            = "external"
#       }
#       "databases" = {
#         "cardanodbsync" = "dmtrdb"
#       }
#       "postgresql" = {
#         "version"    = "14"
#         "parameters" = var.postgres_params
#       }
#       "users" = {
#         "dmtrdb" = [
#           "superuser",
#           "createdb",
#           "login"
#         ],
#         "dmtrro" = [
#           "login"
#         ]
#       }
#       "resources" = {
#         "limits"   = var.postgres_resources.limits
#         "requests" = var.postgres_resources.requests
#       }
#       "volume" = {
#         "storageClass" = var.postgres_volume.storage_class
#         "size"         = var.postgres_volume.size
#       }
#       ""
#       sidecars = [
#         {
#           name : "exporter"
#           image : "quay.io/prometheuscommunity/postgres-exporter:v0.12.0"
#           env : [
#             {
#               name : "DATA_SOURCE_URI"
#               value : "localhost:5432/cardanodbsync?sslmode=disable"
#             },
#             {
#               name : "DATA_SOURCE_USER"
#               value : "$(POSTGRES_USER)"
#             },
#             {
#               name : "DATA_SOURCE_PASS"
#               value : "$(POSTGRES_PASSWORD)"
#             },
#             {
#               name : "PG_EXPORTER_CONSTANT_LABELS"
#               value : "service=dbsync-${local.postgres_host}"
#             }
#           ]
#           ports : [
#             {
#               name : "metrics"
#               containerPort : 9187
#             }
#           ]
#         }
#       ]
#     }
#   }
# }
