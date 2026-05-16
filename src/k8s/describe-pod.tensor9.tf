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

variable "POD" {
  type        = string
  description = "Pod name"
  validation {
    condition     = can(regex("^[a-z0-9.\\-]+$", var.POD))
    error_message = "POD must be a DNS-safe pod name"
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

data "aws_eks_cluster" "target" { name = var.CLUSTER }
data "aws_eks_cluster_auth" "target" { name = var.CLUSTER }

provider "kubernetes" {
  host                   = data.aws_eks_cluster.target.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.target.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.target.token
}

resource "tensor9_command" "this" {
  name        = "describe-pod"
  display     = "Describe pod"
  description = "Single-pod drill-down: phase, conditions, scheduling, per-container state (image, ready, restartCount, waiting/terminated reasons). Read-only equivalent of `kubectl describe pod` minus the events tail — pair with `get-events` for the timeline."
  icon        = "info"
  data_access = ["Infrastructure"]
}

data "kubernetes_resource" "pod" {
  api_version = "v1"
  kind        = "Pod"
  metadata {
    name      = var.POD
    namespace = var.NAMESPACE
  }
}

output "pod" {
  value = {
    name       = try(data.kubernetes_resource.pod.object.metadata.name, null)
    namespace  = try(data.kubernetes_resource.pod.object.metadata.namespace, null)
    phase      = try(data.kubernetes_resource.pod.object.status.phase, null)
    node       = try(data.kubernetes_resource.pod.object.spec.nodeName, "")
    pod_ip     = try(data.kubernetes_resource.pod.object.status.podIP, "")
    host_ip    = try(data.kubernetes_resource.pod.object.status.hostIP, "")
    qos_class  = try(data.kubernetes_resource.pod.object.status.qosClass, "")
    created    = try(data.kubernetes_resource.pod.object.metadata.creationTimestamp, "")
    started    = try(data.kubernetes_resource.pod.object.status.startTime, "")
    owner_kind = try(data.kubernetes_resource.pod.object.metadata.ownerReferences[0].kind, "")
    owner_name = try(data.kubernetes_resource.pod.object.metadata.ownerReferences[0].name, "")
    labels     = try(data.kubernetes_resource.pod.object.metadata.labels, {})
    conditions = try([
      for c in data.kubernetes_resource.pod.object.status.conditions : {
        type                 = c.type
        status               = c.status
        reason               = try(c.reason, "")
        message              = try(c.message, "")
        last_transition_time = try(c.lastTransitionTime, "")
      }
    ], [])
    containers = try([
      for c in data.kubernetes_resource.pod.object.status.containerStatuses : {
        name          = c.name
        image         = c.image
        ready         = try(c.ready, false)
        restart_count = try(c.restartCount, 0)
        started       = try(c.started, false)
        state_running = try({
          started_at = c.state.running.startedAt
        }, null)
        state_waiting = try({
          reason  = c.state.waiting.reason
          message = try(c.state.waiting.message, "")
        }, null)
        state_terminated = try({
          reason      = c.state.terminated.reason
          exit_code   = c.state.terminated.exitCode
          message     = try(c.state.terminated.message, "")
          started_at  = try(c.state.terminated.startedAt, "")
          finished_at = try(c.state.terminated.finishedAt, "")
        }, null)
      }
    ], [])
    init_containers = try([
      for c in data.kubernetes_resource.pod.object.status.initContainerStatuses : {
        name          = c.name
        image         = c.image
        ready         = try(c.ready, false)
        restart_count = try(c.restartCount, 0)
        state_waiting = try({
          reason  = c.state.waiting.reason
          message = try(c.state.waiting.message, "")
        }, null)
        state_terminated = try({
          reason    = c.state.terminated.reason
          exit_code = c.state.terminated.exitCode
        }, null)
      }
    ], [])
  }
}
