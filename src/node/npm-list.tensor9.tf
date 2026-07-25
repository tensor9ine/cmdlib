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
  example_output = <<-EOT
    {
      "name": "acme-api",
      "version": "2.14.3",
      "dependencies": {
        "express": {
          "version": "4.19.2",
          "dependencies": {
            "body-parser": { "version": "1.20.2" },
            "cookie": { "version": "0.6.0" },
            "finalhandler": { "version": "1.2.0" }
          }
        },
        "pg": {
          "version": "8.11.5",
          "dependencies": {
            "pg-pool": { "version": "3.6.2" },
            "pg-protocol": { "version": "1.6.1" }
          }
        },
        "ioredis": {
          "version": "5.4.1",
          "dependencies": {
            "cluster-key-slot": { "version": "1.1.2" },
            "denque": { "version": "2.1.0" }
          }
        },
        "pino": {
          "version": "9.1.0",
          "dependencies": {
            "sonic-boom": { "version": "4.0.1" },
            "pino-std-serializers": { "version": "7.0.0" }
          }
        },
        "@aws-sdk/client-s3": {
          "version": "3.596.0",
          "dependencies": {
            "@smithy/smithy-client": { "version": "3.1.1" }
          }
        }
      }
    }
  EOT
}

resource "null_resource" "list" {
  triggers = {
    cluster   = var.CLUSTER
    pod       = var.POD
    namespace = var.NAMESPACE
    container = var.CONTAINER
    depth     = var.DEPTH
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      aws eks update-kubeconfig --name ${var.CLUSTER} --region ${data.aws_region.current.region} >/dev/null
      kubectl exec ${var.POD} -n ${var.NAMESPACE} ${var.CONTAINER == "" ? "" : "-c ${var.CONTAINER}"} -- \
        npm ls --depth=${var.DEPTH} --json
    EOT
  }
}
