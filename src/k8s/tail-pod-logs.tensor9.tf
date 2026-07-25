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
  description = "Pod name to tail logs from"
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
  name        = "tail-pod-logs"
  display     = "Tail pod logs"
  description = "Fetch the trailing 2 MiB of logs (up to 20000 lines) from a Kubernetes pod for triage. Read-only."
  icon        = "logs"
  data_access = ["Logs"]
  example_output = <<-EOT
    2026-07-25T14:30:59.001Z INFO  starting api server on :8080 (build v2.4.0)
    2026-07-25T14:31:00.140Z INFO  connected to postgres acme-prod.cluster-abc123.us-east-1.rds.amazonaws.com:5432
    2026-07-25T14:31:44.902Z INFO  GET /v1/orders 200 12ms
    2026-07-25T14:31:59.610Z INFO  GET /v1/orders/8821 200 7ms
    2026-07-25T14:32:05.010Z INFO  GET /healthz 200 1ms
    2026-07-25T14:32:12.777Z WARN  cache miss for key session:9f2c1a; falling back to db
    2026-07-25T14:32:18.443Z INFO  POST /v1/checkout 201 34ms
  EOT
}

resource "null_resource" "tail" {
  triggers = {
    cluster   = var.CLUSTER
    pod       = var.POD
    namespace = var.NAMESPACE
    container = var.CONTAINER
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      aws eks update-kubeconfig --name ${var.CLUSTER} --region ${data.aws_region.current.region} >/dev/null
      kubectl logs ${var.POD} -n ${var.NAMESPACE} ${var.CONTAINER == "" ? "" : "-c ${var.CONTAINER}"} --tail=20000 \
        | tail -c 2097152
    EOT
  }
}
