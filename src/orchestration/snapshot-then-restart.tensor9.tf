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
  description = "EKS cluster name hosting the API deployment"
  validation {
    condition     = can(regex("^[A-Za-z0-9-]+$", var.CLUSTER))
    error_message = "CLUSTER must be a valid EKS cluster name"
  }
}

variable "DB_VOLUME_ID" {
  type        = string
  description = "EBS volume id backing the database (vol-...)"
  validation {
    condition     = can(regex("^vol-[0-9a-f]+$", var.DB_VOLUME_ID))
    error_message = "DB_VOLUME_ID must look like vol-<hex>"
  }
}

variable "API_DEPLOYMENT" {
  type        = string
  default     = "api"
  description = "Deployment name to bounce after the snapshot completes"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.API_DEPLOYMENT))
    error_message = "API_DEPLOYMENT must be lowercase alphanumeric"
  }
}

variable "NAMESPACE" {
  type        = string
  default     = "production"
  description = "Kubernetes namespace of the API deployment"
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
  name         = "snapshot-then-restart"
  display      = "Snapshot DB then restart API"
  description  = "Take an EBS snapshot of the database volume, then bounce the API deployment once the snapshot is complete. Use before risky migrations so the restart picks up new schema with a clean recovery point."
  icon         = "shield-check"
  data_access  = ["Infrastructure", "Storage"]
  side_effects = ["ebs-snapshot", "pod-restarts"]
  example_output = <<-EOT
    ==> Step 1/2: Snapshotting DB volume vol-0f1e2d3c4b5a69788
        snapshot snap-0a1b2c3d4e5f6a7b8 created from vol-0f1e2d3c4b5a69788
        waiting for state=completed... completed (22s)
    ==> Step 2/2: Restarting deployment.apps/api in namespace production
        annotated deployment.apps/api: kubectl.kubernetes.io/restartedAt=2026-07-25T14:44:10Z
        annotated deployment.apps/api: tensor9.com/snapshot-id=snap-0a1b2c3d4e5f6a7b8
    ✓ Completed in 26s — snapshot snap-0a1b2c3d4e5f6a7b8, api restarted
  EOT
}

resource "aws_ebs_snapshot" "db" {
  volume_id   = var.DB_VOLUME_ID
  description = "pre-restart snapshot for ${var.API_DEPLOYMENT}@${var.NAMESPACE}"
  tags = {
    Name      = "t9-prerestart-${var.DB_VOLUME_ID}"
    CreatedBy = "tensor9-ops-cmd"
    Purpose   = "snapshot-then-restart"
  }
}

resource "kubernetes_annotations" "rollout_trigger" {
  api_version = "apps/v1"
  kind        = "Deployment"
  metadata {
    name      = var.API_DEPLOYMENT
    namespace = var.NAMESPACE
  }
  annotations = {
    "kubectl.kubernetes.io/restartedAt" = timestamp()
    "tensor9.com/snapshot-id"           = aws_ebs_snapshot.db.id
  }

  depends_on = [aws_ebs_snapshot.db]
}

output "snapshot_id" {
  value = aws_ebs_snapshot.db.id
}

output "restarted_at" {
  value = kubernetes_annotations.rollout_trigger.annotations["kubectl.kubernetes.io/restartedAt"]
}
