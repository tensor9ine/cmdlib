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
  description = "Kubernetes namespace to list services from"
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
  name        = "list-services"
  display     = "List services"
  description = "Every Service in NAMESPACE with type, clusterIP, externalIPs, exposed ports, and selector — answers `is anything routable to this workload?`. Quick `kubectl get svc -o wide` equivalent."
  icon        = "list"
  data_access = ["Infrastructure"]
}

data "kubernetes_resources" "services" {
  api_version = "v1"
  kind        = "Service"
  namespace   = var.NAMESPACE
}

output "services" {
  value = [
    for s in data.kubernetes_resources.services.objects : {
      name          = try(s.metadata.name, "")
      namespace     = try(s.metadata.namespace, "")
      type          = try(s.spec.type, "ClusterIP")
      cluster_ip    = try(s.spec.clusterIP, "")
      external_ips  = try(s.spec.externalIPs, [])
      external_name = try(s.spec.externalName, "")
      selector      = try(s.spec.selector, {})
      ports = try([
        for p in s.spec.ports : {
          name        = try(p.name, "")
          port        = try(p.port, null)
          target_port = try(tostring(p.targetPort), "")
          node_port   = try(p.nodePort, null)
          protocol    = try(p.protocol, "TCP")
        }
      ], [])
      load_balancer_ingress = try([
        for lb in s.status.loadBalancer.ingress : try(lb.hostname, try(lb.ip, ""))
      ], [])
      created = try(s.metadata.creationTimestamp, "")
    }
  ]
}
