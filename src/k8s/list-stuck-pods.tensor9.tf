terraform {
  required_providers {
    tensor9    = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = "~> 2.41" }
    aws        = { source = "hashicorp/aws", version = "~> 5.0" }
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

variable "NAMESPACE" {
  type        = string
  default     = "default"
  description = "Kubernetes namespace to scan"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.NAMESPACE))
    error_message = "NAMESPACE must be a DNS-safe namespace name"
  }
}

variable "MIN_AGE_SECONDS" {
  type        = number
  default     = 300
  description = "Minimum pod age (seconds) before it counts as stuck"
}

data "aws_eks_cluster"      "target" { name = var.CLUSTER }
data "aws_eks_cluster_auth" "target" { name = var.CLUSTER }

provider "kubernetes" {
  host                   = data.aws_eks_cluster.target.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.target.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.target.token
}

resource "tensor9_command" "this" {
  name        = "list-stuck-pods"
  display     = "List stuck pods"
  description = "Pods that haven't been Ready for more than MIN_AGE_SECONDS — common precursor to a rollback or restart"
  icon        = "search"
  data_access = ["Infrastructure"]
}

data "kubernetes_resources" "pods" {
  api_version    = "v1"
  kind           = "Pod"
  namespace      = var.NAMESPACE
  field_selector = "status.phase!=Running"
}

output "stuck_pods" {
  value = [
    for p in data.kubernetes_resources.pods.objects : {
      namespace = p.metadata.namespace
      name      = p.metadata.name
      reason    = try(p.status.containerStatuses[0].state.waiting.reason, "Unknown")
    }
    if (timestamp() - p.metadata.creationTimestamp) > var.MIN_AGE_SECONDS
  ]
}
