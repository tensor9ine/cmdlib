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
