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

# First-touch triage probe: dump the basic facts about the Node process —
# version, PID, uptime, memory usage, argv. Cheap, side-effect free,
# always safe to run as the first step when something looks wrong.

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
  name        = "process-info"
  display     = "Node process info"
  description = "Dump basic Node.js process metadata (version, PID, uptime, memory usage, argv) as JSON. The first template to run when triaging a misbehaving Node app — cheap and entirely side-effect free."
  icon        = "search"
  data_access = ["Infrastructure"]
}

resource "null_resource" "info" {
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
      kubectl exec ${var.POD} -n ${var.NAMESPACE} ${var.CONTAINER == "" ? "" : "-c ${var.CONTAINER}"} -- \
        node -e "console.log(JSON.stringify({version:process.version,pid:process.pid,uptime:process.uptime(),mem:process.memoryUsage(),argv:process.argv,platform:process.platform,arch:process.arch},null,2))"
    EOT
  }
}
