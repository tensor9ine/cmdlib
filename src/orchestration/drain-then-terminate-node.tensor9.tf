terraform {
  required_providers {
    tensor9    = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = "~> 2.41" }
    aws        = { source = "hashicorp/aws", version = "~> 6.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.20" }
    null       = { source = "hashicorp/null", version = "~> 3.2" }
  }
}

provider "tensor9" {
  mode = "ops"
}

provider "aws" {}

variable "CLUSTER" {
  type        = string
  description = "EKS cluster name hosting the node"
  validation {
    condition     = can(regex("^[A-Za-z0-9-]+$", var.CLUSTER))
    error_message = "CLUSTER must be a valid EKS cluster name"
  }
}

variable "NODE_NAME" {
  type        = string
  description = "Kubernetes node name to cordon and drain (e.g. ip-10-0-1-23.ec2.internal)"
  validation {
    condition     = can(regex("^[a-z0-9.\\-]+$", var.NODE_NAME))
    error_message = "NODE_NAME must be a DNS-safe node name"
  }
}

variable "INSTANCE_ID" {
  type        = string
  description = "EC2 instance id backing the node (i-...)"
  validation {
    condition     = can(regex("^i-[0-9a-f]+$", var.INSTANCE_ID))
    error_message = "INSTANCE_ID must look like i-<hex>"
  }
}

variable "GRACE_PERIOD_SECONDS" {
  type        = number
  default     = 60
  description = "Pod termination grace period during eviction"
  validation {
    condition     = var.GRACE_PERIOD_SECONDS >= 0 && var.GRACE_PERIOD_SECONDS <= 3600
    error_message = "GRACE_PERIOD_SECONDS must be between 0 and 3600"
  }
}

data "aws_region" "current" {}
data "aws_eks_cluster" "target" { name = var.CLUSTER }
data "aws_eks_cluster_auth" "target" { name = var.CLUSTER }

provider "kubernetes" {
  host                   = data.aws_eks_cluster.target.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.target.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.target.token
}

resource "tensor9_command" "this" {
  name         = "drain-then-terminate-node"
  display      = "Drain then terminate node"
  description  = "Cordon and drain a Kubernetes node, then terminate the underlying EC2 instance. Pods are evicted respecting their PDBs and grace period before the instance is destroyed, so workloads land on healthy nodes first."
  icon         = "shield"
  data_access  = ["Infrastructure"]
  side_effects = ["node-drain", "ec2-termination"]
  example_output = <<-EOT
    ==> Step 1/2: Draining node ip-10-0-12-34.ec2.internal (grace period 60s)
        Updated context arn:aws:eks:us-east-1:123456789012:cluster/acme-prod in ~/.kube/config
        node/ip-10-0-12-34.ec2.internal cordoned
        evicting pod app/web-7d9f6c8b5d-n2kqv
        evicting pod app/api-5c7b9f4a21-8mzpr
        evicting pod app/worker-6b8d4f9c73-lp4xw
        pod/web-7d9f6c8b5d-n2kqv evicted
        pod/api-5c7b9f4a21-8mzpr evicted
        pod/worker-6b8d4f9c73-lp4xw evicted
        node/ip-10-0-12-34.ec2.internal drained
    ==> Step 2/2: Terminating EC2 instance i-0abc12345def67890 (m6i.2xlarge)
        i-0abc12345def67890: running -> shutting-down
    ✓ Completed in 1m22s — node drained, instance terminating
  EOT
}

resource "null_resource" "drain" {
  triggers = {
    cluster = var.CLUSTER
    node    = var.NODE_NAME
    grace   = var.GRACE_PERIOD_SECONDS
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      aws eks update-kubeconfig --name ${var.CLUSTER} --region ${data.aws_region.current.region} >/dev/null
      kubectl drain ${var.NODE_NAME} \
        --ignore-daemonsets \
        --delete-emptydir-data \
        --grace-period=${var.GRACE_PERIOD_SECONDS} \
        --timeout=10m
    EOT
  }
}

resource "null_resource" "terminate" {
  depends_on = [null_resource.drain]

  triggers = {
    instance_id = var.INSTANCE_ID
    drained_at  = null_resource.drain.triggers.run_at
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      aws ec2 terminate-instances \
        --region ${data.aws_region.current.region} \
        --instance-ids ${var.INSTANCE_ID}
    EOT
  }
}

output "drained_node" {
  value = var.NODE_NAME
}

output "terminated_instance_id" {
  value = var.INSTANCE_ID
}
