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
  example_output = <<-EOT
    2026-07-25T14:29:58.113Z WARN  (api/1): pg pool: acquire slow (1274ms), 20/20 connections in use — pool exhausted
    2026-07-25T14:30:02.451Z WARN  (api/1): ioredis reconnecting (attempt 3) to redis.acme-prod.svc.cluster.local:6379
    2026-07-25T14:30:12.889Z DEBUG (api/1): cache miss for key user:$${userId} — falling back to pg
    2026-07-25T14:30:12.903Z ERROR (api/1): unhandledRejection: TimeoutError: Redis command timed out
        at Timeout._onTimeout (/app/node_modules/ioredis/built/Command.js:184:33)
        at listOnTimeout (node:internal/timers:573:17)
        at process.processTimers (node:internal/timers:514:7)
    2026-07-25T14:31:05.220Z ERROR (api/1): TypeError: Cannot read properties of undefined (reading 'id')
        at getUser (/app/dist/handlers/user.js:42:19)
        at process.processTicksAndRejections (node:internal/process/task_queues:95:5)
    (node:1) MaxListenersExceededWarning: Possible EventEmitter memory leak detected. 11 error listeners added to [Socket]. Use emitter.setMaxListeners() to increase limit
  EOT
}

resource "null_resource" "tail" {
  triggers = {
    cluster   = var.CLUSTER
    pod       = var.POD
    namespace = var.NAMESPACE
    container = var.CONTAINER
    lines     = var.LINES
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      aws eks update-kubeconfig --name ${var.CLUSTER} --region ${data.aws_region.current.region} >/dev/null
      # kubectl logs interleaves stdout+stderr by default; Node typically writes
      # errors / warnings to stderr — the operator filters downstream as needed.
      kubectl logs ${var.POD} -n ${var.NAMESPACE} -c ${var.CONTAINER} --tail=${var.LINES}
    EOT
  }
}
