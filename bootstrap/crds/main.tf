resource "kubernetes_manifest" "customresourcedefinition_dbsyncports_demeter_run" {
  manifest = {
    "apiVersion" = "apiextensions.k8s.io/v1"
    "kind" = "CustomResourceDefinition"
    "metadata" = {
      "name" = "dbsyncports.demeter.run"
    }
    "spec" = {
      "group" = "demeter.run"
      "names" = {
        "categories" = []
        "kind" = "DbSyncPort"
        "plural" = "dbsyncports"
        "shortNames" = []
        "singular" = "dbsyncport"
      }
      "scope" = "Namespaced"
      "versions" = [
        {
          "additionalPrinterColumns" = []
          "name" = "v1"
          "schema" = {
            "openAPIV3Schema" = {
              "description" = "Auto-generated derived type for DbSyncPortSpec via `CustomResource`"
              "properties" = {
                "spec" = {
                  "properties" = {
                    "network" = {
                      "enum" = [
                        "mainnet",
                        "preprod",
                        "preview",
                      ]
                      "type" = "string"
                    }
                  }
                  "required" = [
                    "network",
                  ]
                  "type" = "object"
                }
                "status" = {
                  "nullable" = true
                  "properties" = {
                    "password" = {
                      "type" = "string"
                    }
                    "username" = {
                      "type" = "string"
                    }
                  }
                  "required" = [
                    "password",
                    "username",
                  ]
                  "type" = "object"
                }
              }
              "required" = [
                "spec",
              ]
              "title" = "DbSyncPort"
              "type" = "object"
            }
          }
          "served" = true
          "storage" = true
          "subresources" = {
            "status" = {}
          }
        },
      ]
    }
  }
}
