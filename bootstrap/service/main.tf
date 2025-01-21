variable "namespace" {
  type = string
}

variable "cloud_provider" {
  default = "aws"
}

variable "instance_role" {
  type    = string
  default = "pgbouncer"
}

variable "load_balancer" {
  default = false
}

variable "service_name" {
  default = "dbsync-v3-pgbouncer"
}

resource "kubernetes_service_v1" "dbsync_v3_service_aws" {
  for_each = var.cloud_provider == "aws" ? toset(["loadbalancer"]) : toset([])
  metadata {
    namespace = var.namespace
    name      = var.service_name
    annotations = {
      "beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "instance"
      "service.beta.kubernetes.io/aws-load-balancer-scheme"  = "internet-facing"
      "service.beta.kubernetes.io/aws-load-balancer-type"    = "external"
    }
  }

  spec {
    type                = "LoadBalancer"
    load_balancer_class = "service.k8s.aws/nlb"

    port {
      protocol    = "TCP"
      port        = 5432
      target_port = 6432
    }

    selector = {
      "role" = "pgbouncer"
    }
  }
}

resource "kubernetes_service_v1" "dbsync_v3_service_gcp" {
  for_each = var.cloud_provider == "gcp" ? toset(["loadbalancer"]) : toset([])
  metadata {
    namespace = var.namespace
    name      = var.service_name
    annotations = {
      "cloud.google.com/l4-rbs" : "enabled"
      # Added for terraform not to complain on every apply
      "cloud.google.com/neg" = jsonencode({
        ingress = true
      })
    }
  }

  spec {
    type                    = "LoadBalancer"
    external_traffic_policy = "Local"

    port {
      protocol    = "TCP"
      port        = 5432
      target_port = 6432
    }

    selector = {
      "role" = var.instance_role
    }
  }
}

resource "kubernetes_service_v1" "postgres_service" {
  metadata {
    name      = "dbsync-blockfrost-postgres"
    namespace = var.namespace
  }

  spec {
    type = "ClusterIP"
    selector = {
      role                  = "postgres"
      is_blockfrost_backend = "true"
    }

    port {
      port        = 5432
      target_port = 5432
      name        = "postgres"
    }
  }
}
