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
  description = "Kubernetes namespace"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.NAMESPACE))
    error_message = "NAMESPACE must be a DNS-safe namespace name"
  }
}

variable "LIMIT" {
  type        = number
  default     = 50
  description = "Max events to return (most recent first)"
  validation {
    condition     = var.LIMIT > 0 && var.LIMIT <= 500
    error_message = "LIMIT must be between 1 and 500"
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
  name        = "get-events"
  display     = "Get warning events"
  description = "Pull the most recent Warning-type events in a namespace — the fastest way to see what the control plane is unhappy about (FailedScheduling, OOMKilled, ImagePullBackOff, etc.)."
  icon        = "alert"
  data_access = ["Infrastructure"]
  example_output = <<-EOT
    LAST SEEN   OBJECT                        REASON             MESSAGE
    25s         pod/api-7f9c8d4b6-r3ntv       BackOff            Back-off restarting failed container "api" in pod api-7f9c8d4b6-r3ntv
    2m          pod/web-5d8c9f7b4-9d2wq       Failed             Failed to pull image "acme/web:v2.4.1": manifest unknown
    4m          pod/web-5d8c9f7b4-9d2wq       ImagePullBackOff   Back-off pulling image "acme/web:v2.4.1"
    9m          pod/worker-6b7d8c9f5-zz9xx    FailedScheduling   0/3 nodes are available: 3 Insufficient cpu
    16m         pod/api-7f9c8d4b6-p8wqz       Unhealthy          Liveness probe failed: Get "http://10.0.45.102:8080/healthz": dial tcp 10.0.45.102:8080: connect: connection refused
  EOT
}

data "kubernetes_resources" "events" {
  api_version    = "v1"
  kind           = "Event"
  namespace      = var.NAMESPACE
  field_selector = "type=Warning"
}

locals {
  sorted_events = reverse(sort([
    for e in data.kubernetes_resources.events.objects :
    "${e.lastTimestamp}|${e.involvedObject.kind}/${e.involvedObject.name}|${e.reason}|${e.message}"
  ]))
}

output "events" {
  value = [
    for line in slice(local.sorted_events, 0, min(var.LIMIT, length(local.sorted_events))) :
    {
      ts      = split("|", line)[0]
      object  = split("|", line)[1]
      reason  = split("|", line)[2]
      message = split("|", line)[3]
    }
  ]
}
