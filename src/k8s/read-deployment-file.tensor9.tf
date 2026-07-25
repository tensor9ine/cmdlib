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
  description = "Deployment name whose pods should be read"
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

variable "FILE_PATH" {
  type        = string
  description = "Absolute path to a file inside each pod's container filesystem (same path across all pods)"
}

variable "MAX_BYTES_PER_POD" {
  type        = number
  default     = 1048576
  description = "Per-pod cap on bytes read (1 KiB to 10 MiB). Default 1 MiB. Total output ≈ MAX_BYTES_PER_POD × pod count + per-pod headers."
  validation {
    condition     = var.MAX_BYTES_PER_POD >= 1024 && var.MAX_BYTES_PER_POD <= 10485760
    error_message = "MAX_BYTES_PER_POD must be between 1024 (1 KiB) and 10485760 (10 MiB)."
  }
}

data "aws_region" "current" {}

resource "tensor9_command" "this" {
  name        = "read-deployment-file"
  display     = "Read file across deployment pods"
  description = "Read the same file from every pod of a Kubernetes Deployment for triage. Each pod's output is prefixed with its name so you can attribute / diff. Read-only — no mutation of pod state."
  icon        = "file-text"
  data_access = ["Logs", "Infrastructure"]
  example_output = <<-EOT
    ----- pod/web-5d8c9f7b4-2xq9p -----
    server:
      listen: 0.0.0.0:8080
      workers: 4
    upstream:
      api: http://api.default.svc.cluster.local:8080
    log_level: info
    ----- pod/web-5d8c9f7b4-7bkzr -----
    server:
      listen: 0.0.0.0:8080
      workers: 4
    upstream:
      api: http://api.default.svc.cluster.local:8080
    log_level: info
    ----- pod/web-5d8c9f7b4-t4m8n -----
    server:
      listen: 0.0.0.0:8080
      workers: 4
    upstream:
      api: http://api.default.svc.cluster.local:8080
    log_level: debug
  EOT
}

resource "null_resource" "read" {
  triggers = {
    cluster           = var.CLUSTER
    deployment        = var.DEPLOYMENT
    namespace         = var.NAMESPACE
    container         = var.CONTAINER
    file_path         = var.FILE_PATH
    max_bytes_per_pod = var.MAX_BYTES_PER_POD
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      aws eks update-kubeconfig --name ${var.CLUSTER} --region ${data.aws_region.current.region} >/dev/null

      container_flag=""
      if [ -n "${var.CONTAINER}" ]; then container_flag="-c ${var.CONTAINER}"; fi

      # Enumerate pods via the deployment's matchLabels selector. Same shape
      # as the fallback path in tail-deployment-logs.tensor9.tf — kubectl
      # has no native "exec across all pods" verb.
      selector=$(kubectl get deployment/${var.DEPLOYMENT} -n ${var.NAMESPACE} \
        -o jsonpath='{.spec.selector.matchLabels}' \
        | sed 's/[{}"]//g' | sed 's/:/=/g')

      for pod in $(kubectl get pods -n ${var.NAMESPACE} -l "$selector" -o name); do
        printf -- '----- %s -----\n' "$pod"
        kubectl exec "$pod" -n ${var.NAMESPACE} $container_flag -- \
          sh -c 'head -c ${var.MAX_BYTES_PER_POD} "${var.FILE_PATH}" 2>&1 || true' \
          | head -c ${var.MAX_BYTES_PER_POD} || true
        printf '\n'
      done
    EOT
  }
}
