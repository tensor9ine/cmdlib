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

variable "REPLICAS" {
  type        = number
  description = "Target replica count (0 to 100)"
  validation {
    condition     = var.REPLICAS >= 0 && var.REPLICAS <= 100
    error_message = "REPLICAS must be between 0 and 100"
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
  name         = "scale-deployment"
  display      = "Scale deployment"
  description  = "Set the replica count of a Kubernetes deployment. Use REPLICAS=0 to drain a deployment without deleting it."
  icon         = "scale"
  data_access  = ["Infrastructure"]
  side_effects = ["pod-scaling"]
}

resource "kubernetes_annotations" "scale_marker" {
  api_version = "apps/v1"
  kind        = "Deployment"
  metadata {
    name      = var.DEPLOYMENT
    namespace = var.NAMESPACE
  }
  annotations = {
    "tensor9.com/scaled-to-at" = "${var.REPLICAS}@${timestamp()}"
  }
}

resource "null_resource" "scale" {
  depends_on = [kubernetes_annotations.scale_marker]
  triggers = {
    target_replicas = var.REPLICAS
    target_marker   = kubernetes_annotations.scale_marker.annotations["tensor9.com/scaled-to-at"]
  }
  provisioner "local-exec" {
    command = "kubectl scale deployment/${var.DEPLOYMENT} -n ${var.NAMESPACE} --replicas=${var.REPLICAS}"
  }
}
