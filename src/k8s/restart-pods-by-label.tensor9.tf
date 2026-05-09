terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = ">= 2.40.0" }
    aws     = { source = "hashicorp/aws" }
    null    = { source = "hashicorp/null" }
  }
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
  description = "Kubernetes namespace"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.NAMESPACE))
    error_message = "NAMESPACE must be a DNS-safe namespace name"
  }
}

variable "LABEL_SELECTOR" {
  type        = string
  description = "Label selector matching pods to restart, e.g. app=api,tier=frontend"
  validation {
    condition     = can(regex("^[a-zA-Z0-9_.\\-/=,!]+$", var.LABEL_SELECTOR))
    error_message = "LABEL_SELECTOR must contain only label-syntax characters"
  }
}

data "aws_region" "current" {}

resource "tensor9_command" "this" {
  name         = "restart-pods-by-label"
  display      = "Restart pods by label"
  description  = "Delete all pods matching a label selector so their owning controller recreates them. Useful for forcing a config-reload across a fleet of pods that share labels but no single Deployment."
  icon         = "refresh"
  data_access  = ["Infrastructure"]
  side_effects = ["pod-restarts"]
}

resource "null_resource" "restart" {
  triggers = {
    cluster   = var.CLUSTER
    namespace = var.NAMESPACE
    selector  = var.LABEL_SELECTOR
    run_at    = timestamp()
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      aws eks update-kubeconfig --name ${var.CLUSTER} --region ${data.aws_region.current.name} >/dev/null
      kubectl delete pod -n ${var.NAMESPACE} \
        -l '${var.LABEL_SELECTOR}' \
        --ignore-not-found
    EOT
  }
}
