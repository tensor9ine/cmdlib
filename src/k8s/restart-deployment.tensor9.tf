terraform {
  required_providers {
    tensor9    = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = "~> 2.41" }
    aws        = { source = "hashicorp/aws", version = "~> 6.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.20" }
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
  description = "Deployment name"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.DEPLOYMENT))
    error_message = "DEPLOYMENT must be lowercase alphanumeric"
  }
}

variable "NAMESPACE" {
  type        = string
  default     = "production"
  description = "Kubernetes namespace"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.NAMESPACE))
    error_message = "NAMESPACE must be a DNS-safe namespace name"
  }
}

data "aws_eks_cluster" "target" { name = var.CLUSTER }
data "aws_eks_cluster_auth" "target" { name = var.CLUSTER }

provider "kubernetes" {
  host                   = data.aws_eks_cluster.target.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.target.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.target.token
}

resource "tensor9_command" "this" {
  name         = "restart-deployment"
  display      = "Restart deployment"
  description  = "Bounce the pods of a Kubernetes deployment by patching the rollout-restartedAt annotation. Triggers a rolling restart; existing connections drain per the deployment's configured terminationGracePeriodSeconds."
  icon         = "refresh"
  data_access  = ["Infrastructure"]
  side_effects = ["pod-restarts"]
}

resource "kubernetes_annotations" "rollout_trigger" {
  api_version = "apps/v1"
  kind        = "Deployment"
  metadata {
    name      = var.DEPLOYMENT
    namespace = var.NAMESPACE
  }
  annotations = {
    "kubectl.kubernetes.io/restartedAt" = timestamp()
  }
}

output "restarted_at" {
  value = kubernetes_annotations.rollout_trigger.annotations["kubectl.kubernetes.io/restartedAt"]
}
