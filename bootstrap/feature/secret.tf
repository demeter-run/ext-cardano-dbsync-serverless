resource "random_password" "postgres" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "dmtrro" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "kubernetes_secret" "postgres" {
  metadata {
    name      = "postgres.${var.instance_name}"
    namespace = var.namespace
  }
  data = {
    "password" = random_password.postgres.result
  }
  type = "Opaque"
}

resource "kubernetes_secret" "dmtrro" {
  metadata {
    name      = "dmtrro.${var.instance_name}"
    namespace = var.namespace
  }
  data = {
    "password" = random_password.dmtrro.result
  }
  type = "Opaque"
}