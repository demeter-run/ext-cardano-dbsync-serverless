variable "namespace" {
  description = "the namespace where the resources will be created"
}

variable "volume_name" {
  description = "the name of the volume"
}

variable "name" {
  description = "the name of the pvc"
}

variable "storage_size" {
  description = "the size of the volume"
}

variable "storage_class" {
  default = "nvme"
}

variable "access_mode" {
  default = "ReadWriteMany"
}

resource "kubernetes_persistent_volume_claim" "shared_disk" {
  wait_until_bound = false

  metadata {
    name      = var.name
    namespace = var.namespace
  }

  spec {
    access_modes = [var.access_mode]
    resources {
      requests = {
        storage = var.storage_size
      }
    }
    storage_class_name = var.storage_class
    volume_name        = var.volume_name
  }
}
