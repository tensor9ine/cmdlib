terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = ">= 2.41.0" }
    aws     = { source = "hashicorp/aws" }
    null    = { source = "hashicorp/null" }
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

variable "NODE_NAME" {
  type        = string
  description = "Node to cordon and drain (e.g. ip-10-0-1-23.ec2.internal)"
  validation {
    condition     = can(regex("^[a-z0-9.\\-]+$", var.NODE_NAME))
    error_message = "NODE_NAME must be a DNS-safe node name"
  }
}

variable "GRACE_PERIOD_SECONDS" {
  type        = number
  default     = 60
  description = "Pod termination grace period during eviction"
  validation {
    condition     = var.GRACE_PERIOD_SECONDS >= 0 && var.GRACE_PERIOD_SECONDS <= 3600
    error_message = "GRACE_PERIOD_SECONDS must be between 0 and 3600"
  }
}

data "aws_region" "current" {}

resource "tensor9_command" "this" {
  name         = "drain-node"
  display      = "Drain node"
  description  = "Cordon a Kubernetes node and evict its pods. DaemonSet pods are skipped; emptyDir-backed pods are deleted. Use before terminating an EC2 instance for maintenance."
  icon         = "shield"
  data_access  = ["Infrastructure"]
  side_effects = ["node-drain", "pod-evictions"]
}

resource "null_resource" "drain" {
  triggers = {
    cluster   = var.CLUSTER
    node      = var.NODE_NAME
    grace     = var.GRACE_PERIOD_SECONDS
    run_at    = timestamp()
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      aws eks update-kubeconfig --name ${var.CLUSTER} --region ${data.aws_region.current.name} >/dev/null
      kubectl drain ${var.NODE_NAME} \
        --ignore-daemonsets \
        --delete-emptydir-data \
        --grace-period=${var.GRACE_PERIOD_SECONDS} \
        --timeout=10m
    EOT
  }
}
