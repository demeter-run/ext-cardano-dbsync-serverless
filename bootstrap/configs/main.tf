terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
  }
}

variable "network" {
  description = "cardano node network"
}

variable "salt" {
  description = "random value to avoid naming conflicts between instances"
}

variable "namespace" {
  description = "the namespace where the resources will be created"
}

locals {
  cm_name = "configs-${var.network}-${var.salt}"
}

resource "kubernetes_config_map" "node-config" {
  metadata {
    namespace = var.namespace
    name      = local.cm_name
  }

  data = {
    "config.json"         = "${file("${path.module}/${var.network}/config.json")}"
    "db-sync-config.json" = "${file("${path.module}/${var.network}/db-sync-config.json")}"
  }
}

output "cm_name" {
  value = local.cm_name
}
