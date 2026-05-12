terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = "~> 2.41" }
    aws     = { source = "hashicorp/aws", version = "~> 6.0" }
    null    = { source = "hashicorp/null", version = "~> 3.2" }
  }
}

provider "tensor9" {
  mode = "ops"
}

provider "aws" {}

variable "DAYS" {
  type        = number
  default     = 30
  description = "Snapshots older than this many days are returned"
  validation {
    condition     = var.DAYS > 0 && var.DAYS <= 3650
    error_message = "DAYS must be between 1 and 3650"
  }
}

data "aws_caller_identity" "current" {}

resource "tensor9_command" "this" {
  name        = "list-old-snapshots"
  display     = "List old EBS snapshots"
  description = "Find EBS snapshots owned by this account that are older than DAYS — input for snapshot-cleanup audits. Read-only."
  icon        = "search"
  data_access = ["Storage"]
}

# aws-provider 6.x removed the `aws_ebs_snapshots` (plural) data
# source; fall back to the AWS CLI via local-exec.
# `ec2 describe-snapshots --owner-ids self` is the same read-only
# call the data source used to wrap, just returned on stdout.
resource "null_resource" "scan" {
  triggers = {
    days       = var.DAYS
    account_id = data.aws_caller_identity.current.account_id
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      # Compute the cutoff in UTC ISO-8601 so the AWS CLI's StartTime
      # comparison works exactly. macOS `date -v` vs GNU `date -d` fork.
      cutoff=$(date -u -v-${var.DAYS}d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "-${var.DAYS} days" +%Y-%m-%dT%H:%M:%SZ)
      printf 'snapshot_id\tvolume_id\tstart_time\tsize_gib\n'
      aws ec2 describe-snapshots --owner-ids ${data.aws_caller_identity.current.account_id} \
        --query "Snapshots[?StartTime<='$cutoff'].[SnapshotId,VolumeId,StartTime,VolumeSize]" \
        --output text
      printf '\ncutoff: %s\n' "$cutoff"
    EOT
  }
}
