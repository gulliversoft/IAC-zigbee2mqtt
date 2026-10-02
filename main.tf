terraform {
  required_providers {
    kubernetes = {
        source = "hashicorp/kubernetes"
    }
  }
}
provider "kubernetes" {
    config_path = "~/.kube/config"
    config_context = "minikube"
}
variable "namespace" {
  description = "k8s namespace used in this deployment"
  type = string
  default = "garden"
}
variable "deployment_name" {
    description = "k8s deployment"
    type = string
    default = "terraformed-garden-plant"
}
variable "app_label" {
  description = "resources bundle by name"
  type = string
  default = "plantApp"
}
variable "replica_count" {
    description = "Number of replicas kept"
    type = number
    default = 1
}
variable "zigbee2mqtt_image" {
    description = "docker image used"
    type = string
    default = "ghcr.io/koenkk/zigbee2mqtt:2.9.2"
}
variable "resource_requests_cpu" {
  description = "CPU requests for the container"
  type        = string
  default     = "250m"
}

variable "resource_requests_memory" {
  description = "Memory requests for the container"
  type        = string
  default     = "50Mi"
}

variable "resource_limits_cpu" {
  description = "CPU limits for the container"
  type        = string
  default     = "500m"
}

variable "resource_limits_memory" {
  description = "Memory limits for the container"
  type        = string
  default     = "512Mi"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner annotation for resources"
  type        = string
  default     = "systemlord"
}


############################
# KUBERNETES OUTPUTS
############################

output "namespace_name" {
  description = "The name of the created Kubernetes namespace"
  value       = kubernetes_namespace_v1.plant-res.metadata[0].name
}

output "namespace_uid" {
  description = "The UID of the created Kubernetes namespace"
  value       = kubernetes_namespace_v1.plant-res.metadata[0].uid
}

# Removed namespace_status output as status is not directly accessible

output "deployment_name" {
  description = "The name of the created Kubernetes deployment"
  value       = kubernetes_deployment_v1.plant-res.metadata[0].name
}

output "deployment_generation" {
  description = "The generation of the deployment"
  value       = kubernetes_deployment_v1.plant-res.metadata[0].generation
}

output "deployment_replicas" {
  description = "The number of replicas in the deployment"
  value       = kubernetes_deployment_v1.plant-res.spec[0].replicas
}

# Removed status-related outputs as they are not directly accessible in the provider

output "service_name" {
  description = "The name of the created Kubernetes service"
  value       = kubernetes_service_v1.plant-res.metadata[0].name
}

output "service_cluster_ip" {
  description = "The cluster IP of the service"
  value       = kubernetes_service_v1.plant-res.spec[0].cluster_ip
}

output "service_ports" {
  description = "The ports exposed by the service"
  value       = kubernetes_service_v1.plant-res.spec[0].port[*].port
}

output "resource_quota_status" {
  description = "The status of the resource quota"
  value       = kubernetes_resource_quota_v1.plant-res.spec[0].hard
}

output "kubernetes_connection_info" {
  description = "Information about the Kubernetes connection"
  value = {
    config_path    = "~/.kube/config"
    config_context = "minikube"
  }
  sensitive = false
}

output "service_endpoint" {
  description = "How to access the service (instructions)"
  value       = "To access the service within the cluster, use: ${kubernetes_service_v1.plant-res.metadata[0].name}.${kubernetes_namespace_v1.plant-res.metadata[0].name}.svc.cluster.local"
}

output "deployment_labels" {
  description = "Labels applied to the deployment"
  value       = kubernetes_deployment_v1.plant-res.metadata[0].labels
}

output "pod_security_settings" {
  description = "Security settings applied to the pods"
  value = {
    run_as_non_root           = false
    read_only_root_filesystem = false
  }
}
############################
# NAMESPACE
############################

resource "kubernetes_namespace_v1" "plant-res" {
  metadata {
    name = var.namespace
    labels = {
      environment = var.environment
    }
    annotations = {
      owner = var.owner
    }
  }
}

########################################
# RESOURCE QUOTA & LIMIT RANGE (optional)
########################################

resource "kubernetes_resource_quota_v1" "plant-res" {
  metadata {
    name      = "rq-plant-res"
    namespace = kubernetes_namespace_v1.plant-res.metadata[0].name
  }
  spec {
    hard = {
      "pods"            = 10
      "requests.cpu"    = "2"
      "requests.memory" = "2Gi"
      "limits.cpu"      = "4"
      "limits.memory"   = "4Gi"
    }
  }
}

resource "kubernetes_limit_range_v1" "plant-res" {
  metadata {
    name      = "lr-plant-res"
    namespace = kubernetes_namespace_v1.plant-res.metadata[0].name
  }
  spec {
    limit {
      type = "Container"
      default = {
        cpu    = var.resource_limits_cpu
        memory = var.resource_limits_memory
      }
      default_request = {
        cpu    = var.resource_requests_cpu
        memory = var.resource_requests_memory
      }
    }
  }
}

resource "kubernetes_deployment_v1" "plant-res" {
  metadata {
    name      = var.deployment_name
    namespace = kubernetes_namespace_v1.plant-res.metadata[0].name
    labels = {
      app         = var.app_label
      environment = var.environment
    }
    annotations = {
      owner = var.owner
    }
  }

  spec {
    replicas = var.replica_count

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = 0
        max_unavailable = 1
      }
    }

    selector {
      match_labels = {
        app = var.app_label
      }
    }

    template {
      metadata {
        labels = {
          app         = var.app_label
          environment = var.environment
        }
        annotations = {
          owner = var.owner
        }
      }

      spec {

        container {
          name  = "zigbee2mqtt"
          image = var.zigbee2mqtt_image
          env {
            name  = "TZ"
            value = "Europe/Amsterdam"
          }

          volume_mount {
            name       = "data"
            mount_path = "/app/data"
          }

          volume_mount {
            name       = "udev"
            mount_path = "/run/udev"
            read_only  = true
          }

          volume_mount {
            name       = "usb-device"
            mount_path = "/dev/ttyACM0"
          }

          port {
            container_port = 8080
          }

          resources {
            limits = {
              cpu    = var.resource_limits_cpu
              memory = var.resource_limits_memory
            }
            requests = {
              cpu    = var.resource_requests_cpu
              memory = var.resource_requests_memory
            }
          }

          startup_probe {
            http_get {
              path = "/"
              port = 8080
            }
            initial_delay_seconds = 30
            failure_threshold = 30
            period_seconds    = 10
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 8080
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 8080
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }

        volume {
          name = "data"
          host_path {
            path = "/data/zigbee2mqtt"
            type = "DirectoryOrCreate"
          }
        }

        volume {
          name = "udev"
          host_path {
            path = "/run/udev"
            type = "DirectoryOrCreate"
          }
        }

        volume {
          name = "usb-device"
          host_path {
            path = "/dev/serial/by-id/usb-ITead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_f625fb2cb79aef118f91b89061ce3355-if00-port0"
            type = "CharDevice"
          }
        }
      }
    }
  }
}

############################
# SERVICE (to expose pods)
############################

resource "kubernetes_service_v1" "plant-res" {
  metadata {
    name      = "${var.deployment_name}-svc"
    namespace = kubernetes_namespace_v1.plant-res.metadata[0].name
    labels = {
      app = var.app_label
    }
  }

  spec {
    selector = {
      app = var.app_label
    }
    port {
      name        = "zigbee2mqtt"
      port        = 8080
      target_port = 8080
      node_port   = 30080
      protocol    = "TCP"
    }
    type = "NodePort"
  }
}
