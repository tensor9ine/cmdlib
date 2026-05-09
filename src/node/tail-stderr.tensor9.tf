terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = ">= 2.40.0" }
    aws     = { source = "hashicorp/aws" }
    null    = { source = "hashicorp/null" }
  }
}

provider "aws" {}

# Targeted variant of tail-pod-logs — pulls only the trailing LINES of the
# named container's stream. Required CONTAINER (Node apps in multi-container
# pods often co-run a sidecar; we want the app's stream specifically).

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
  description = "Pod hosting the Node.js process"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.POD))
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

variable "CONTAINER" {
  type        = string
  description = "Container name within the pod (required — pick the Node app container explicitly)"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.CONTAINER))
    error_message = "CONTAINER must be a DNS-safe container name"
  }
}

variable "LINES" {
  type        = number
  default     = 200
  description = "Number of trailing log lines to fetch"
  validation {
    condition     = var.LINES >= 1 && var.LINES <= 10000
    error_message = "LINES must be between 1 and 10000"
  }
}

data "aws_region" "current" {}

resource "tensor9_command" "this" {
  name        = "tail-stderr"
  display     = "Tail Node container stderr"
  description = "Fetch the trailing LINES of stderr-side log output from a specific container in a pod. Distinct from the generic tail-pod-logs in that CONTAINER is required, so multi-container pods (app + sidecar) yield the app stream unambiguously."
  icon        = "logs"
  data_access = ["Logs"]
}

resource "null_resource" "tail" {
  triggers = {
    cluster   = var.CLUSTER
    pod       = var.POD
    namespace = var.NAMESPACE
    container = var.CONTAINER
    lines     = var.LINES
    run_at    = timestamp()
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      aws eks update-kubeconfig --name ${var.CLUSTER} --region ${data.aws_region.current.name} >/dev/null
      # kubectl logs interleaves stdout+stderr by default; Node typically writes
      # errors / warnings to stderr — the operator filters downstream as needed.
      kubectl logs ${var.POD} -n ${var.NAMESPACE} -c ${var.CONTAINER} --tail=${var.LINES}
    EOT
  }
}
