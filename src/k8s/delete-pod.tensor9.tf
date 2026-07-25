terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = "~> 2.41" }
    aws     = { source = "hashicorp/aws", version = "~> 6.0" }
    null    = { source = "hashicorp/null", version = "~> 3.2" }
  }
}

provider "tensor9" {
  mode = "ops"
}

provider "aws" {}

variable "CLUSTER" {
  type        = string
  description = "EKS cluster name"
  validation {
    condition     = can(regex("^[A-Za-z0-9-]+$", var.CLUSTER))
    error_message = "CLUSTER must be a valid EKS cluster name"
  }
}

variable "POD" {
  type        = string
  description = "Pod name to delete"
  validation {
    condition     = can(regex("^[a-z0-9.\\-]+$", var.POD))
    error_message = "POD must be a DNS-safe pod name"
  }
}

variable "NAMESPACE" {
  type        = string
  default     = "default"
  description = "Kubernetes namespace"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.NAMESPACE))
    error_message = "NAMESPACE must be a DNS-safe namespace name"
  }
}

variable "GRACE_PERIOD_SECONDS" {
  type        = number
  default     = 30
  description = "Pod termination grace period. Set to 0 for `--force --grace-period=0` (forcible delete — for stuck pods that won't drain normally)."
  validation {
    condition     = var.GRACE_PERIOD_SECONDS >= 0 && var.GRACE_PERIOD_SECONDS <= 3600
    error_message = "GRACE_PERIOD_SECONDS must be between 0 and 3600"
  }
}

data "aws_region" "current" {}

resource "tensor9_command" "this" {
  name         = "delete-pod"
  display      = "Delete pod"
  description  = "Delete a single pod by name. If the pod is owned by a ReplicaSet/Deployment/StatefulSet it'll be recreated; this is the standard `force a single instance to restart` move when restart-pods-by-label is too broad. GRACE_PERIOD_SECONDS=0 forces an immediate delete for pods stuck in Terminating."
  icon         = "trash"
  data_access  = ["Infrastructure"]
  side_effects = ["pod-deletion"]
  example_output = <<-EOT
    pod "api-7f9c8d4b6-xk2m9" deleted
  EOT
}

resource "null_resource" "delete" {
  triggers = {
    cluster   = var.CLUSTER
    pod       = var.POD
    namespace = var.NAMESPACE
    grace     = var.GRACE_PERIOD_SECONDS
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      aws eks update-kubeconfig --name ${var.CLUSTER} --region ${data.aws_region.current.region} >/dev/null
      if [ "${var.GRACE_PERIOD_SECONDS}" = "0" ]; then
        kubectl delete pod ${var.POD} \
          --namespace=${var.NAMESPACE} \
          --force \
          --grace-period=0 \
          --ignore-not-found
      else
        kubectl delete pod ${var.POD} \
          --namespace=${var.NAMESPACE} \
          --grace-period=${var.GRACE_PERIOD_SECONDS} \
          --ignore-not-found
      fi
    EOT
  }
}
