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
  description = "Deployment name to roll back"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.DEPLOYMENT))
    error_message = "DEPLOYMENT must be lowercase alphanumeric"
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

variable "TO_REVISION" {
  type        = number
  default     = 0
  description = "Target revision (0 = previous revision, the default `kubectl rollout undo` behavior). Use `kubectl rollout history deploy/<name>` to find specific revisions."
  validation {
    condition     = var.TO_REVISION >= 0
    error_message = "TO_REVISION must be non-negative"
  }
}

data "aws_region" "current" {}

resource "tensor9_command" "this" {
  name         = "rollback-deployment"
  display      = "Rollback deployment"
  description  = "Revert a Deployment to its previous (or specified) revision via `kubectl rollout undo`. Triggers a rolling restart with the previous PodTemplateSpec; existing connections drain per terminationGracePeriodSeconds. Pair with `describe-deployment` afterward to verify the rollout."
  icon         = "rewind"
  data_access  = ["Infrastructure"]
  side_effects = ["pod-restarts", "rollout-rollback"]
  example_output = <<-EOT
    deployment.apps/api rolled back
    Waiting for deployment "api" rollout to finish: 2 out of 4 new replicas have been updated...
    Waiting for deployment "api" rollout to finish: 3 out of 4 new replicas have been updated...
    Waiting for deployment "api" rollout to finish: 1 old replicas are pending termination...
    deployment "api" successfully rolled out
  EOT
}

resource "null_resource" "rollback" {
  triggers = {
    cluster     = var.CLUSTER
    deployment  = var.DEPLOYMENT
    namespace   = var.NAMESPACE
    to_revision = var.TO_REVISION
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      aws eks update-kubeconfig --name ${var.CLUSTER} --region ${data.aws_region.current.region} >/dev/null
      if [ "${var.TO_REVISION}" = "0" ]; then
        kubectl rollout undo deployment/${var.DEPLOYMENT} --namespace=${var.NAMESPACE}
      else
        kubectl rollout undo deployment/${var.DEPLOYMENT} \
          --namespace=${var.NAMESPACE} \
          --to-revision=${var.TO_REVISION}
      fi
      kubectl rollout status deployment/${var.DEPLOYMENT} \
        --namespace=${var.NAMESPACE} \
        --timeout=5m
    EOT
  }
}
