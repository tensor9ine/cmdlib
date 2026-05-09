terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = ">= 2.40.0" }
    aws     = { source = "hashicorp/aws" }
    null    = { source = "hashicorp/null" }
  }
}

provider "aws" {}

# Dump `npm ls --json` from inside the running container. Distinct from
# inspecting package.json in the source tree because what is *deployed* may
# differ from what is *locked* — e.g., postinstall scripts, peer-dep
# resolution, multi-stage Docker builds that drop dev deps. Useful for
# answering "did the deploy actually pick up the version bump?".

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

variable "DEPTH" {
  type        = number
  default     = 1
  description = "Dependency tree depth (0 = top-level only)"
  validation {
    condition     = var.DEPTH >= 0 && var.DEPTH <= 10
    error_message = "DEPTH must be between 0 and 10"
  }
}

data "aws_region" "current" {}

resource "tensor9_command" "this" {
  name        = "npm-list"
  display     = "List installed npm packages"
  description = "Run `npm ls --json --depth=DEPTH` inside the running Node container to dump the *actually deployed* dependency tree. Read-only; useful for confirming a version bump landed or chasing a phantom transitive dep."
  icon        = "package"
  data_access = ["Infrastructure"]
}

resource "null_resource" "list" {
  triggers = {
    cluster   = var.CLUSTER
    pod       = var.POD
    namespace = var.NAMESPACE
    container = var.CONTAINER
    depth     = var.DEPTH
    run_at    = timestamp()
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      aws eks update-kubeconfig --name ${var.CLUSTER} --region ${data.aws_region.current.name} >/dev/null
      kubectl exec ${var.POD} -n ${var.NAMESPACE} ${var.CONTAINER == "" ? "" : "-c ${var.CONTAINER}"} -- \
        npm ls --depth=${var.DEPTH} --json
    EOT
  }
}
