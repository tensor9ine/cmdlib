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

variable "VOLUME_ID" {
  type        = string
  description = "EBS volume id to snapshot and resize (vol-...)"
  validation {
    condition     = can(regex("^vol-[0-9a-f]+$", var.VOLUME_ID))
    error_message = "VOLUME_ID must look like vol-<hex>"
  }
}

variable "NEW_SIZE_GB" {
  type        = number
  description = "New size in GiB for the volume (must be larger than the current size)"
  validation {
    condition     = var.NEW_SIZE_GB >= 1 && var.NEW_SIZE_GB <= 16384
    error_message = "NEW_SIZE_GB must be between 1 and 16384"
  }
}

data "aws_region" "current" {}

resource "tensor9_command" "this" {
  name         = "snapshot-then-resize-volume"
  display      = "Snapshot then resize volume"
  description  = "Take a point-in-time EBS snapshot, then grow the volume to NEW_SIZE_GB. The snapshot is the rollback path if the live resize wedges the filesystem; nothing here grows the filesystem inside the guest."
  icon         = "database"
  data_access  = ["Storage"]
  side_effects = ["ebs-snapshot", "volume-resize"]
}

resource "aws_ebs_snapshot" "pre_resize" {
  volume_id   = var.VOLUME_ID
  description = "pre-resize snapshot for ${var.VOLUME_ID} -> ${var.NEW_SIZE_GB}GiB"
  tags = {
    Name      = "t9-preresize-${var.VOLUME_ID}"
    CreatedBy = "tensor9-ops-cmd"
    Purpose   = "snapshot-then-resize-volume"
  }
}

resource "null_resource" "modify_volume" {
  depends_on = [aws_ebs_snapshot.pre_resize]

  triggers = {
    volume_id   = var.VOLUME_ID
    new_size_gb = var.NEW_SIZE_GB
    snapshot_id = aws_ebs_snapshot.pre_resize.id
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      aws ec2 modify-volume \
        --region ${data.aws_region.current.region} \
        --volume-id ${var.VOLUME_ID} \
        --size ${var.NEW_SIZE_GB}
    EOT
  }
}

output "snapshot_id" {
  value = aws_ebs_snapshot.pre_resize.id
}

output "resized_volume_id" {
  value = var.VOLUME_ID
}

output "new_size_gb" {
  value = var.NEW_SIZE_GB
}
