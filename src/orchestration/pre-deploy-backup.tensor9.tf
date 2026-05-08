terraform {
  required_providers {
    tensor9    = { source = "tensor9/tensor9" }
    aws        = { source = "hashicorp/aws" }
    kubernetes = { source = "hashicorp/kubernetes" }
    null       = { source = "hashicorp/null" }
  }
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
  description = "Deployment to scale to 0 while the deploy is in progress"
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

variable "PARAMETER_KEY" {
  type        = string
  description = "SSM Parameter Store key to write the deploy-in-progress flag (e.g. /myapp/deploy/state)"
  validation {
    condition     = can(regex("^/[a-zA-Z0-9/_-]+$", var.PARAMETER_KEY))
    error_message = "PARAMETER_KEY must start with / and use alphanumerics, _, -, /"
  }
}

data "aws_region"           "current" {}
data "aws_eks_cluster"      "target"  { name = var.CLUSTER }
data "aws_eks_cluster_auth" "target"  { name = var.CLUSTER }

provider "kubernetes" {
  host                   = data.aws_eks_cluster.target.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.target.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.target.token
}

resource "tensor9_command" "this" {
  name         = "pre-deploy-backup"
  display      = "Pre-deploy backup"
  description  = "Run before a risky deploy: snapshot the DB volume, scale the API to 0 replicas, then write a deploy-in-progress flag to SSM Parameter Store. Strict ordering — if the snapshot fails, the API is never quiesced and the flag is never set."
  icon         = "shield-check"
  data_access  = ["Infrastructure", "Storage"]
  side_effects = ["ebs-snapshot", "pod-scaling", "ssm-write"]
}

resource "aws_ebs_snapshot" "db" {
  volume_id   = var.DB_VOLUME_ID
  description = "pre-deploy snapshot for ${var.API_DEPLOYMENT}@${var.NAMESPACE}"
  tags = {
    Name      = "t9-predeploy-${var.DB_VOLUME_ID}"
    CreatedBy = "tensor9-ops-cmd"
    Purpose   = "pre-deploy-backup"
  }
}

resource "kubernetes_annotations" "quiesce_marker" {
  depends_on = [aws_ebs_snapshot.db]

  api_version = "apps/v1"
  kind        = "Deployment"
  metadata {
    name      = var.API_DEPLOYMENT
    namespace = var.NAMESPACE
  }
  annotations = {
    "tensor9.com/quiesced-at" = timestamp()
    "tensor9.com/snapshot-id" = aws_ebs_snapshot.db.id
  }
}

resource "null_resource" "scale_to_zero" {
  depends_on = [kubernetes_annotations.quiesce_marker]

  triggers = {
    deployment   = var.API_DEPLOYMENT
    namespace    = var.NAMESPACE
    quiesced_at  = kubernetes_annotations.quiesce_marker.annotations["tensor9.com/quiesced-at"]
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      aws eks update-kubeconfig --name ${var.CLUSTER} --region ${data.aws_region.current.name} >/dev/null
      kubectl scale deployment/${var.API_DEPLOYMENT} -n ${var.NAMESPACE} --replicas=0
    EOT
  }
}

resource "aws_ssm_parameter" "deploy_state" {
  depends_on = [null_resource.scale_to_zero]

  name        = var.PARAMETER_KEY
  description = "Tensor9 pre-deploy-backup flag for ${var.API_DEPLOYMENT}"
  type        = "String"
  overwrite   = true
  value = jsonencode({
    state       = "deploy-in-progress"
    snapshot_id = aws_ebs_snapshot.db.id
    deployment  = "${var.NAMESPACE}/${var.API_DEPLOYMENT}"
    set_at      = timestamp()
  })
  tags = {
    CreatedBy = "tensor9-ops-cmd"
    Purpose   = "pre-deploy-backup"
  }
}

output "snapshot_id" {
  value = aws_ebs_snapshot.db.id
}

output "quiesced_at" {
  value = kubernetes_annotations.quiesce_marker.annotations["tensor9.com/quiesced-at"]
}

output "parameter_key" {
  value = aws_ssm_parameter.deploy_state.name
}
