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
  description = "Pod name to read the file from"
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

variable "FILE_PATH" {
  type        = string
  description = "Absolute path to a file inside the pod's container filesystem"
}

variable "MAX_BYTES" {
  type        = number
  default     = 1048576
  description = "Cap on bytes read (1 KiB to 10 MiB). Default 1 MiB."
  validation {
    condition     = var.MAX_BYTES >= 1024 && var.MAX_BYTES <= 10485760
    error_message = "MAX_BYTES must be between 1024 (1 KiB) and 10485760 (10 MiB)."
  }
}

data "aws_region" "current" {}

resource "tensor9_command" "this" {
  name        = "read-pod-file"
  display     = "Read pod file"
  description = "Read a file from inside a specific Kubernetes pod's container filesystem (capped at MAX_BYTES). Read-only — no mutation of pod state."
  icon        = "file-text"
  data_access = ["Logs", "Infrastructure"]
  example_output = <<-EOT
    server:
      listen: 0.0.0.0:8080
      workers: 8
    database:
      host: acme-prod.cluster-abc123.us-east-1.rds.amazonaws.com
      port: 5432
      pool_size: 20
    cache:
      endpoint: acme-prod.abc123.ng.0001.use1.cache.amazonaws.com:6379
    log_level: info
  EOT
}

resource "null_resource" "read" {
  triggers = {
    cluster   = var.CLUSTER
    pod       = var.POD
    namespace = var.NAMESPACE
    container = var.CONTAINER
    file_path = var.FILE_PATH
    max_bytes = var.MAX_BYTES
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      aws eks update-kubeconfig --name ${var.CLUSTER} --region ${data.aws_region.current.region} >/dev/null

      container_flag=""
      if [ -n "${var.CONTAINER}" ]; then container_flag="-c ${var.CONTAINER}"; fi

      # head -c inside the pod caps bytes server-side; the outer pipe is a
      # belt-and-suspenders guard if the container lacks head (busybox does).
      kubectl exec ${var.POD} -n ${var.NAMESPACE} $container_flag -- \
        sh -c 'head -c ${var.MAX_BYTES} "${var.FILE_PATH}"' \
        | head -c ${var.MAX_BYTES}
    EOT
  }
}
