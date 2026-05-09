terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = ">= 2.40.0" }
    aws     = { source = "hashicorp/aws" }
    null    = { source = "hashicorp/null" }
  }
}

provider "aws" {}

# Trigger Node's built-in heap-dump by sending SIGUSR2 to the target process.
# Node writes a Heap.<timestamp>.<pid>.heapsnapshot file into its CWD (/tmp here);
# this template signals the process and then lists the produced file path.
# Operator typically follows up with `kubectl cp` to pull the file out.

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

variable "PID" {
  type        = number
  default     = 1
  description = "Target Node process ID inside the container"
  validation {
    condition     = var.PID >= 1 && var.PID <= 65535
    error_message = "PID must be between 1 and 65535"
  }
}

data "aws_region" "current" {}

resource "tensor9_command" "this" {
  name         = "heap-snapshot"
  display      = "Capture heap snapshot"
  description  = "Send SIGUSR2 to a Node.js process inside a Kubernetes pod to trigger a v8 heap snapshot. Node writes a Heap.*.heapsnapshot file in its CWD (typically /tmp). Use `kubectl cp` afterwards to retrieve it for analysis in Chrome DevTools."
  icon         = "activity"
  data_access  = ["Memory"]
  side_effects = ["heap-snapshot"]
}

resource "null_resource" "snapshot" {
  triggers = {
    cluster   = var.CLUSTER
    pod       = var.POD
    namespace = var.NAMESPACE
    container = var.CONTAINER
    pid       = var.PID
    run_at    = timestamp()
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      aws eks update-kubeconfig --name ${var.CLUSTER} --region ${data.aws_region.current.name} >/dev/null
      kubectl exec ${var.POD} -n ${var.NAMESPACE} ${var.CONTAINER == "" ? "" : "-c ${var.CONTAINER}"} -- kill -USR2 ${var.PID}
      sleep 2
      kubectl exec ${var.POD} -n ${var.NAMESPACE} ${var.CONTAINER == "" ? "" : "-c ${var.CONTAINER}"} -- sh -c 'ls -la /tmp/Heap.*.heapsnapshot 2>/dev/null | tail -n 1'
    EOT
  }
}
