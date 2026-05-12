terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = "~> 2.41" }
    aws        = { source = "hashicorp/aws", version = "~> 6.0" }
    null       = { source = "hashicorp/null", version = "~> 3.2" }
  }
}

provider "tensor9" {
  mode = "ops"
}

provider "aws" {}

# Toggle GC tracing on a Node process for DURATION_SECONDS. Node only emits
# --trace-gc style output if the app was launched with that flag, or if the
# app itself wired up a v8 GCEventCallback hook listening for SIGUSR1.
# Without one of those, this template is a no-op — document this clearly in
# the operator runbook before relying on the output.

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

variable "DURATION_SECONDS" {
  type        = number
  default     = 30
  description = "How long to leave GC tracing enabled before disabling"
  validation {
    condition     = var.DURATION_SECONDS >= 1 && var.DURATION_SECONDS <= 600
    error_message = "DURATION_SECONDS must be between 1 and 600"
  }
}

data "aws_region" "current" {}

resource "tensor9_command" "this" {
  name         = "gc-trace"
  display      = "Toggle GC tracing"
  description  = "Send SIGUSR1 to a Node process to toggle GC tracing on, sleep DURATION_SECONDS, then send SIGUSR1 again to toggle it off. NOTE: the app must have been started with --trace-gc OR have wired up a v8 GC callback for this signal to actually emit output — otherwise it's a no-op."
  icon         = "thermometer"
  data_access  = ["Metrics"]
  side_effects = ["gc-trace-toggle"]
}

resource "null_resource" "gc_trace" {
  triggers = {
    cluster   = var.CLUSTER
    pod       = var.POD
    namespace = var.NAMESPACE
    container = var.CONTAINER
    duration  = var.DURATION_SECONDS
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      aws eks update-kubeconfig --name ${var.CLUSTER} --region ${data.aws_region.current.region} >/dev/null
      KEXEC="kubectl exec ${var.POD} -n ${var.NAMESPACE} ${var.CONTAINER == "" ? "" : "-c ${var.CONTAINER}"} --"
      echo "enabling gc trace"
      $KEXEC kill -USR1 1
      sleep ${var.DURATION_SECONDS}
      echo "disabling gc trace"
      $KEXEC kill -USR1 1
    EOT
  }
}
