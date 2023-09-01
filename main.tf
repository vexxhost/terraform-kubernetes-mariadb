# Copyright (c) 2023 VEXXHOST, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.23.0"
    }
  }
}

locals {
  labels = merge(var.labels, {
    "app.kubernetes.io/instance"   = var.name
    "app.kubernetes.io/managed-by" = "terraform-kubernetes-mariadb"
  })
}

resource "kubernetes_service" "service" {
  metadata {
    name      = var.name
    namespace = var.namespace
  }

  spec {
    selector = local.labels

    port {
      port        = 3306
      target_port = 3306
    }
  }
}

resource "kubernetes_secret" "secret" {
  metadata {
    name      = var.name
    namespace = kubernetes_service.service.metadata[0].namespace
  }

  data = {
    root = var.root_password
  }
}

resource "kubernetes_stateful_set" "stateful_set" {
  #ts:skip=AC_K8S_0064 https://github.com/tenable/terrascan/issues/1610

  metadata {
    name      = var.name
    namespace = kubernetes_service.service.metadata[0].namespace
  }

  spec {
    replicas     = 1
    service_name = kubernetes_service.service.metadata[0].name

    selector {
      match_labels = local.labels
    }

    template {
      metadata {
        labels = local.labels
      }

      spec {
        container {
          name  = "mariadb"
          image = "mariadb:11"

          env {
            name = "MYSQL_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.secret.metadata[0].name
                key  = "root"
              }
            }
          }

          readiness_probe {
            initial_delay_seconds = 5
            period_seconds        = 5

            tcp_socket {
              port = 3306
            }
          }
        }
      }
    }
  }
}
