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

# Measure event-loop lag by spawning a short-lived Node helper inside the pod
# (in a *separate* node process, not the app's). This is a coarse proxy: high
# lag here implies the host/container is starved, but does not directly probe
# the running app's loop. Useful for ruling out container-level CPU starvation.

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
  description = "Pod to probe"
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

variable "SAMPLES" {
  type        = number
  default     = 10
  description = "Number of lag samples to collect"
  validation {
    condition     = var.SAMPLES >= 1 && var.SAMPLES <= 100
    error_message = "SAMPLES must be between 1 and 100"
  }
}

data "aws_region" "current" {}

resource "tensor9_command" "this" {
  name        = "event-loop-lag"
  display     = "Measure event-loop lag"
  description = "Sample event-loop lag (setImmediate scheduling latency) SAMPLES times inside the target Node container. Outputs one `lag_ms: N` line per sample. Read-only; useful for diagnosing container-level CPU starvation."
  icon        = "thermometer"
  data_access = ["Metrics"]
}

resource "null_resource" "probe" {
  triggers = {
    cluster   = var.CLUSTER
    pod       = var.POD
    namespace = var.NAMESPACE
    container = var.CONTAINER
    samples   = var.SAMPLES
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      aws eks update-kubeconfig --name ${var.CLUSTER} --region ${data.aws_region.current.region} >/dev/null
      kubectl exec ${var.POD} -n ${var.NAMESPACE} ${var.CONTAINER == "" ? "" : "-c ${var.CONTAINER}"} -- \
        node -e "let n=${var.SAMPLES};(function tick(){if(!n--)return;const s=Date.now();setImmediate(()=>{console.log('lag_ms:',Date.now()-s);setTimeout(tick,100);});})();"
    EOT
  }
}
