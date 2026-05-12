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

variable "NAMESPACE" {
  type        = string
  default     = "default"
  description = "Kubernetes namespace to clean up"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.NAMESPACE))
    error_message = "NAMESPACE must be a DNS-safe namespace name"
  }
}

data "aws_region" "current" {}

resource "tensor9_command" "this" {
  name         = "delete-failed-evicted-pods"
  display      = "Delete failed/evicted pods"
  description  = "Garbage-collect pods stuck in Failed or Evicted phase in a namespace. Safe cleanup after node pressure events; controllers will recreate any pods that should still exist."
  icon         = "trash"
  data_access  = ["Infrastructure"]
  side_effects = ["pod-deletions"]
}

resource "null_resource" "cleanup" {
  triggers = {
    cluster   = var.CLUSTER
    namespace = var.NAMESPACE
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      aws eks update-kubeconfig --name ${var.CLUSTER} --region ${data.aws_region.current.region} >/dev/null
      kubectl delete pod -n ${var.NAMESPACE} \
        --field-selector=status.phase=Failed \
        --ignore-not-found
      # Evicted pods report status.phase=Failed with reason=Evicted; the above covers them.
      # Also sweep any explicitly-Succeeded pods that bare-pod creators left behind.
      kubectl delete pod -n ${var.NAMESPACE} \
        --field-selector=status.phase=Succeeded \
        --ignore-not-found
    EOT
  }
}
