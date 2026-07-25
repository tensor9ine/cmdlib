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
  example_output = <<-EOT
    NAME                     READY   STATUS    RESTARTS      AGE   IP            NODE
    api-7f9c8d4b6-xk2m9      1/1     Running   0             3d    10.0.12.77    ip-10-0-12-34.ec2.internal
    api-7f9c8d4b6-p8wqz      1/1     Running   0             3d    10.0.45.102   ip-10-0-45-67.ec2.internal
    api-7f9c8d4b6-r3ntv      1/1     Running   2 (5h ago)    3d    10.0.89.140   ip-10-0-89-10.ec2.internal
    api-7f9c8d4b6-9jhcd      1/1     Running   0             3d    10.0.12.201   ip-10-0-12-34.ec2.internal
    web-5d8c9f7b4-2xq9p      1/1     Running   0             3d    10.0.12.51    ip-10-0-12-34.ec2.internal
    web-5d8c9f7b4-7bkzr      1/1     Running   0             3d    10.0.45.88    ip-10-0-45-67.ec2.internal
    web-5d8c9f7b4-t4m8n      1/1     Running   0             3d    10.0.89.23    ip-10-0-89-10.ec2.internal
    worker-6b7d8c9f5-hs2kq   1/1     Running   0             12h   10.0.45.55    ip-10-0-45-67.ec2.internal
    worker-6b7d8c9f5-mn4pl   1/1     Running   0             12h   10.0.89.66    ip-10-0-89-10.ec2.internal
  EOT
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
      ready = format("%d/%d",
        length([for c in try(p.status.containerStatuses, []) : c if try(c.ready, false)]),
        length(try(p.status.containerStatuses, [])),
      )
      restarts = sum(concat([0], [for c in try(p.status.containerStatuses, []) : try(c.restartCount, 0)]))
      created  = try(p.metadata.creationTimestamp, "")
    }
  ]
}
