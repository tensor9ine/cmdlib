terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = "~> 2.41" }
    aws        = { source = "hashicorp/aws", version = "~> 5.0" }
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

data "aws_ebs_snapshots" "owned" {
  owners = [data.aws_caller_identity.current.account_id]
}

data "aws_ebs_snapshot" "by_id" {
  for_each   = toset(data.aws_ebs_snapshots.owned.ids)
  snapshot_ids = [each.value]
}

locals {
  cutoff = timeadd(timestamp(), "-${var.DAYS * 24}h")
}

output "old_snapshots" {
  value = [
    for id in data.aws_ebs_snapshots.owned.ids : {
      snapshot_id = id
      volume_id   = data.aws_ebs_snapshot.by_id[id].volume_id
      start_time  = data.aws_ebs_snapshot.by_id[id].start_time
      size_gib    = data.aws_ebs_snapshot.by_id[id].volume_size
    }
    if data.aws_ebs_snapshot.by_id[id].start_time < local.cutoff
  ]
}

output "cutoff_timestamp" {
  value = local.cutoff
}
