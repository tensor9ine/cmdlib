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

data "aws_eks_cluster" "target" { name = var.CLUSTER }
data "aws_eks_cluster_auth" "target" { name = var.CLUSTER }

provider "kubernetes" {
  host                   = data.aws_eks_cluster.target.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.target.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.target.token
}

resource "tensor9_command" "this" {
  name        = "list-nodes"
  display     = "List nodes"
  description = "Cluster-wide node inventory: capacity, allocatable, conditions, taints, instance type, and kernel/kubelet versions. Answers `is the cluster healthy?` in one shot."
  icon        = "list"
  data_access = ["Infrastructure"]
  example_output = <<-EOT
    NAME                         STATUS   ROLES    AGE   VERSION   INTERNAL-IP   INSTANCE-TYPE   ZONE         KERNEL-VERSION                    CONTAINER-RUNTIME
    ip-10-0-12-34.ec2.internal   Ready    <none>   28d   v1.29.6   10.0.12.34    m6i.2xlarge     us-east-1a   6.1.102-108.177.amzn2023.x86_64   containerd://1.7.11
    ip-10-0-45-67.ec2.internal   Ready    <none>   28d   v1.29.6   10.0.45.67    m6i.2xlarge     us-east-1b   6.1.102-108.177.amzn2023.x86_64   containerd://1.7.11
    ip-10-0-89-10.ec2.internal   Ready    <none>   28d   v1.29.6   10.0.89.10    m6i.2xlarge     us-east-1c   6.1.102-108.177.amzn2023.x86_64   containerd://1.7.11
  EOT
}

data "kubernetes_resources" "nodes" {
  api_version = "v1"
  kind        = "Node"
}

output "nodes" {
  value = [
    for n in data.kubernetes_resources.nodes.objects : {
      name              = try(n.metadata.name, "")
      instance_type     = try(n.metadata.labels["node.kubernetes.io/instance-type"], "")
      zone              = try(n.metadata.labels["topology.kubernetes.io/zone"], "")
      created           = try(n.metadata.creationTimestamp, "")
      kubelet_version   = try(n.status.nodeInfo.kubeletVersion, "")
      kernel_version    = try(n.status.nodeInfo.kernelVersion, "")
      os_image          = try(n.status.nodeInfo.osImage, "")
      container_runtime = try(n.status.nodeInfo.containerRuntimeVersion, "")
      capacity = {
        cpu               = try(n.status.capacity.cpu, "")
        memory            = try(n.status.capacity.memory, "")
        pods              = try(n.status.capacity.pods, "")
        ephemeral_storage = try(n.status.capacity["ephemeral-storage"], "")
      }
      allocatable = {
        cpu               = try(n.status.allocatable.cpu, "")
        memory            = try(n.status.allocatable.memory, "")
        pods              = try(n.status.allocatable.pods, "")
        ephemeral_storage = try(n.status.allocatable["ephemeral-storage"], "")
      }
      taints = try([
        for t in n.spec.taints : {
          key    = t.key
          value  = try(t.value, "")
          effect = t.effect
        }
      ], [])
      conditions = try([
        for c in n.status.conditions : {
          type    = c.type
          status  = c.status
          reason  = try(c.reason, "")
          message = try(c.message, "")
        }
      ], [])
      unschedulable = try(n.spec.unschedulable, false)
    }
  ]
}
