terraform {
  required_providers {
    tensor9    = { source = "tensor9/tensor9" }
    aws        = { source = "hashicorp/aws" }
    kubernetes = { source = "hashicorp/kubernetes" }
  }
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
  description = "Deployment name"
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

data "aws_eks_cluster"      "target" { name = var.CLUSTER }
data "aws_eks_cluster_auth" "target" { name = var.CLUSTER }

provider "kubernetes" {
  host                   = data.aws_eks_cluster.target.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.target.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.target.token
}

resource "tensor9_command" "this" {
  name        = "describe-deployment"
  display     = "Describe deployment"
  description = "Full status snapshot of a Deployment: replica counts, rollout conditions, strategy, image, and selector. Read-only equivalent of `kubectl describe deploy`."
  icon        = "info"
  data_access = ["Infrastructure"]
}

data "kubernetes_resource" "deployment" {
  api_version = "apps/v1"
  kind        = "Deployment"
  metadata {
    name      = var.DEPLOYMENT
    namespace = var.NAMESPACE
  }
}

output "deployment" {
  value = {
    name              = try(data.kubernetes_resource.deployment.object.metadata.name, null)
    namespace         = try(data.kubernetes_resource.deployment.object.metadata.namespace, null)
    generation        = try(data.kubernetes_resource.deployment.object.metadata.generation, null)
    desired_replicas  = try(data.kubernetes_resource.deployment.object.spec.replicas, null)
    strategy          = try(data.kubernetes_resource.deployment.object.spec.strategy.type, null)
    selector          = try(data.kubernetes_resource.deployment.object.spec.selector.matchLabels, {})
    images            = try([for c in data.kubernetes_resource.deployment.object.spec.template.spec.containers : c.image], [])
    status = {
      replicas             = try(data.kubernetes_resource.deployment.object.status.replicas, 0)
      ready_replicas       = try(data.kubernetes_resource.deployment.object.status.readyReplicas, 0)
      available_replicas   = try(data.kubernetes_resource.deployment.object.status.availableReplicas, 0)
      updated_replicas     = try(data.kubernetes_resource.deployment.object.status.updatedReplicas, 0)
      unavailable_replicas = try(data.kubernetes_resource.deployment.object.status.unavailableReplicas, 0)
      observed_generation  = try(data.kubernetes_resource.deployment.object.status.observedGeneration, null)
    }
    conditions = try([
      for c in data.kubernetes_resource.deployment.object.status.conditions : {
        type    = c.type
        status  = c.status
        reason  = try(c.reason, "")
        message = try(c.message, "")
      }
    ], [])
  }
}
