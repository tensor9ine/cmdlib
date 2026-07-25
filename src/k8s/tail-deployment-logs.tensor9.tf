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

variable "DEPLOYMENT" {
  type        = string
  description = "Deployment name to aggregate logs from across all pods"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.DEPLOYMENT))
    error_message = "DEPLOYMENT must be a DNS-safe deployment name"
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
  description = "Container name within each pod (empty = first container)"
  validation {
    condition     = var.CONTAINER == "" || can(regex("^[a-z0-9-]+$", var.CONTAINER))
    error_message = "CONTAINER must be empty or a DNS-safe container name"
  }
}

variable "SINCE" {
  type        = string
  default     = "1h"
  description = "How far back to read logs (e.g., 30s, 5m, 1h)"
  validation {
    condition     = can(regex("^[0-9]+[smh]$", var.SINCE))
    error_message = "SINCE must be a duration like 30s, 5m, or 1h"
  }
}

variable "TAIL" {
  type        = string
  default     = "0"
  description = "Max lines per pod (0 = no limit; the bx routes the full output through your blob store)"
  validation {
    condition     = can(regex("^[0-9]+$", var.TAIL))
    error_message = "TAIL must be a non-negative integer"
  }
}

data "aws_region" "current" {}

resource "tensor9_command" "this" {
  name        = "tail-deployment-logs"
  display     = "Tail deployment logs"
  description = "Aggregate recent logs from every pod of a Kubernetes Deployment for triage. Read-only."
  icon        = "logs"
  data_access = ["Logs"]
  example_output = <<-EOT
    [pod/api-7f9c8d4b6-xk2m9/api] 2026-07-25T14:31:02.114Z INFO  starting api server on :8080 (build v2.4.0)
    [pod/api-7f9c8d4b6-xk2m9/api] 2026-07-25T14:31:44.902Z INFO  GET /v1/orders 200 12ms
    [pod/api-7f9c8d4b6-p8wqz/api] 2026-07-25T14:31:45.221Z INFO  GET /v1/orders/8821 200 7ms
    [pod/api-7f9c8d4b6-r3ntv/api] 2026-07-25T14:32:01.550Z ERROR db query failed: dial tcp 10.0.20.15:5432: i/o timeout
    [pod/api-7f9c8d4b6-r3ntv/api] 2026-07-25T14:32:01.551Z WARN  retrying in 500ms (attempt 2/5)
    [pod/api-7f9c8d4b6-9jhcd/api] 2026-07-25T14:32:03.887Z INFO  POST /v1/checkout 201 34ms
    [pod/api-7f9c8d4b6-xk2m9/api] 2026-07-25T14:32:05.010Z INFO  GET /healthz 200 1ms
  EOT
}

resource "null_resource" "tail" {
  triggers = {
    cluster    = var.CLUSTER
    deployment = var.DEPLOYMENT
    namespace  = var.NAMESPACE
    container  = var.CONTAINER
    since      = var.SINCE
    tail       = var.TAIL
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      aws eks update-kubeconfig --name ${var.CLUSTER} --region ${data.aws_region.current.region} >/dev/null

      # Build the per-pod kubectl args; `--all-pods=true --prefix=true` (kubectl
      # >=1.27) aggregates logs across every pod of the Deployment, prefixing
      # each line with `[pod/<name>/<container>]` so the buyer can attribute
      # output. Older kubectl falls through to the loop fallback below.
      tail_flag=""
      if [ "${var.TAIL}" != "0" ]; then tail_flag="--tail=${var.TAIL}"; fi
      container_flag=""
      if [ -n "${var.CONTAINER}" ]; then container_flag="-c ${var.CONTAINER}"; fi

      if kubectl logs deployment/${var.DEPLOYMENT} -n ${var.NAMESPACE} $container_flag \
            --since=${var.SINCE} --all-pods=true --prefix=true $tail_flag 2>/tmp/tdl.err; then
        :
      else
        # Older kubectl that doesn't know --all-pods — fall back to enumerating
        # pods via labels and tailing each in sequence.
        cat /tmp/tdl.err >&2 || true
        selector=$(kubectl get deployment/${var.DEPLOYMENT} -n ${var.NAMESPACE} \
          -o jsonpath='{.spec.selector.matchLabels}' \
          | sed 's/[{}"]//g' | sed 's/:/=/g' | sed 's/,/,/g')
        for pod in $(kubectl get pods -n ${var.NAMESPACE} -l "$selector" -o name); do
          printf -- '----- %s -----\n' "$pod"
          kubectl logs "$pod" -n ${var.NAMESPACE} $container_flag \
            --since=${var.SINCE} $tail_flag || true
        done
      fi
    EOT
  }
}
