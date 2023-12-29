resource "kubernetes_manifest" "postgres_podmonitor" {
  manifest = {
    "apiVersion" = "monitoring.coreos.com/v1"
    "kind"       = "PodMonitor"
    "metadata" = {
      "labels" = {
        "app.kubernetes.io/component" = "o11y"
        "app.kubernetes.io/part-of"   = "demeter"
      }
      "name"      = var.instance_name
      "namespace" = var.namespace
    }
    "spec" = {
      podMetricsEndpoints = [
        {
          port = "metrics",
          path = "/metrics"
        }
      ]
      "selector" = {
        "matchLabels" = {
          "demeter.run/instance" = var.instance_name
        }
      }
    }
  }
}

resource "kubernetes_manifest" "operator_monitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PodMonitor"
    metadata = {
      labels = {
        "app.kubernetes.io/component" = "o11y"
        "app.kubernetes.io/part-of"   = "demeter"
      }
      name      = "operator"
      namespace = var.namespace
    }
    spec = {
      selector = {
        matchLabels = {
          role = "operator"
        }
      }
      podMetricsEndpoints = [
        {
          port = "metrics",
          path = "/metrics"
        }
      ]
    }
  }
}