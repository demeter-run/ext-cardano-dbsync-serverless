variable "namespace" {
  type = string
}

variable "instance_name" {
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

variable "postgres_host_1" {
  type = string
}

variable "postgres_host_2" {
  type = string
}

variable "postgres_secret_name" {
  type = string
}

variable "postgres_password" {
  type = string
}
