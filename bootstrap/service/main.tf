variable "namespace" {
  type = string
}

variable "service_name" {
  default = "dbsync-v3-pgbouncer"
}

resource "kubernetes_service_v1" "dbsync_v3_service" {
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
