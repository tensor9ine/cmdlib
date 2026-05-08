terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9" }
    aws     = { source = "hashicorp/aws" }
    null    = { source = "hashicorp/null" }
  }
}

provider "aws" {}

# List active handles + requests pinning the event loop alive. Caveat: this
# spawns a *fresh* node child via `kubectl exec node -e ...`, which sees its
# own handle table — not the long-running app's. For app-internal handle
# inspection, the inspector-protocol path (cpu-profile pattern) is required.
# This template is still useful as a sanity check on the container itself
# and as an example operators can adapt for in-app observability.

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
  default     = ""
  description = "Container name within the pod (empty = first container)"
  validation {
    condition     = var.CONTAINER == "" || can(regex("^[a-z0-9-]+$", var.CONTAINER))
    error_message = "CONTAINER must be empty or a DNS-safe container name"
  }
}

data "aws_region" "current" {}

resource "tensor9_command" "this" {
  name        = "open-handles"
  display     = "List active handles"
  description = "Enumerate active handles (timers, sockets, file descriptors) and active requests keeping the Node event loop alive via process._getActiveHandles / _getActiveRequests. Useful for diagnosing why a Node process won't exit cleanly."
  icon        = "search"
  data_access = ["Performance"]
}

resource "null_resource" "handles" {
  triggers = {
    cluster   = var.CLUSTER
    pod       = var.POD
    namespace = var.NAMESPACE
    container = var.CONTAINER
    run_at    = timestamp()
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      aws eks update-kubeconfig --name ${var.CLUSTER} --region ${data.aws_region.current.name} >/dev/null
      kubectl exec ${var.POD} -n ${var.NAMESPACE} ${var.CONTAINER == "" ? "" : "-c ${var.CONTAINER}"} -- \
        node -e "console.log(JSON.stringify({handles:process._getActiveHandles().map(h=>h.constructor.name),requests:process._getActiveRequests().map(r=>r.constructor.name)},null,2))"
    EOT
  }
}
