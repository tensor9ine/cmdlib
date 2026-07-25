terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = "~> 2.41" }
    aws     = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}

provider "tensor9" {
  mode = "ops"
}

provider "aws" {}

variable "VOLUME_ID" {
  type        = string
  description = "EBS volume id to snapshot (e.g. vol-0123abcd...)"
  validation {
    condition     = can(regex("^vol-[0-9a-f]+$", var.VOLUME_ID))
    error_message = "VOLUME_ID must look like vol-<hex>"
  }
}

variable "DESCRIPTION" {
  type        = string
  default     = "ad-hoc snapshot via t9 ops cmd"
  description = "Free-form description recorded on the snapshot"
}

resource "tensor9_command" "this" {
  name         = "snapshot-ebs-volume"
  display      = "Snapshot EBS volume"
  description  = "Take a point-in-time EBS snapshot of a volume — useful before risky migrations or in-place data fixes."
  icon         = "shield-check"
  data_access  = ["Storage"]
  side_effects = ["ebs-snapshot"]
  example_output = <<-EOT
    Created EBS snapshot snap-0a1b2c3d4e5f6a7b8 from volume vol-0f1e2d3c4b5a69788.

    SnapshotId    snap-0a1b2c3d4e5f6a7b8
    VolumeId      vol-0f1e2d3c4b5a69788
    State         completed
    Progress      100%
    VolumeSize    200 GiB
    StartTime     2026-07-25T14:30:12Z
    Description   ad-hoc snapshot via t9 ops cmd

    snapshot_id  = snap-0a1b2c3d4e5f6a7b8
    snapshot_arn = arn:aws:ec2:us-east-1:123456789012:snapshot/snap-0a1b2c3d4e5f6a7b8
  EOT
}

resource "aws_ebs_snapshot" "this" {
  volume_id   = var.VOLUME_ID
  description = var.DESCRIPTION
  tags = {
    Name      = "t9-ops-${var.VOLUME_ID}"
    CreatedBy = "tensor9-ops-cmd"
  }
}

output "snapshot_id" {
  value = aws_ebs_snapshot.this.id
}

output "snapshot_arn" {
  value = aws_ebs_snapshot.this.arn
}
