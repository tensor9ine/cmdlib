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

variable "NAMESPACE" {
  type        = string
  default     = "default"
  description = "Kubernetes namespace to list pods from"
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
  name        = "list-pods"
  display     = "List pods"
  description = "Every pod in NAMESPACE with phase, node assignment, IP, and ready-container counts — quick `kubectl get pods -o wide` equivalent"
  icon        = "list"
  data_access = ["Infrastructure"]
}

data "kubernetes_resources" "pods" {
  api_version = "v1"
  kind        = "Pod"
  namespace   = var.NAMESPACE
}

output "pods" {
  value = [
    for p in data.kubernetes_resources.pods.objects : {
      namespace = p.metadata.namespace
      name      = p.metadata.name
      phase     = try(p.status.phase, "Unknown")
      node      = try(p.spec.nodeName, "")
      pod_ip    = try(p.status.podIP, "")
      ready     = format("%d/%d",
        length([for c in try(p.status.containerStatuses, []) : c if try(c.ready, false)]),
        length(try(p.status.containerStatuses, [])),
      )
      restarts  = sum(concat([0], [for c in try(p.status.containerStatuses, []) : try(c.restartCount, 0)]))
      created   = try(p.metadata.creationTimestamp, "")
    }
  ]
}
