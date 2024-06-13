variable "namespace" {
  type = string
}

variable "operator_image_tag" {
  type = string
}

variable "metrics_delay" {
  default = 30
}

variable "dcu_per_second" {
  type = map(string)
  default = {
    "mainnet" = "10"
    "preprod" = "5"
    "preview" = "5"
  }
}


variable "postgres_hosts" {
  type = list(string)
}

variable "postgres_secret_name" {
  type = string
}

variable "postgres_password" {
  type = string
}

variable "pgbouncer_server_crt" {
  type = string
}

variable "pgbouncer_server_key" {
  type = string
}
