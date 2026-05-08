terraform {
  required_providers {
    tensor9 = { source = "tensor9/tensor9" }
    aws     = { source = "hashicorp/aws" }
  }
}

provider "aws" {}

variable "DB_INSTANCE_IDENTIFIER" {
  type        = string
  description = "RDS DB instance identifier to snapshot"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.DB_INSTANCE_IDENTIFIER))
    error_message = "DB_INSTANCE_IDENTIFIER must start with a lowercase letter and contain only lowercase letters, digits, and hyphens"
  }
}

variable "SNAPSHOT_NAME_SUFFIX" {
  type        = string
  default     = "ad-hoc"
  description = "Suffix appended to the generated snapshot identifier"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.SNAPSHOT_NAME_SUFFIX))
    error_message = "SNAPSHOT_NAME_SUFFIX must be lowercase alphanumeric with hyphens"
  }
}

resource "tensor9_command" "this" {
  name         = "rds-snapshot"
  display      = "Snapshot RDS instance"
  description  = "Take a manual RDS snapshot of DB_INSTANCE_IDENTIFIER — useful before risky schema migrations or restoring to a known-good state."
  icon         = "shield-check"
  data_access  = ["Storage"]
  side_effects = ["rds-snapshot"]
}

resource "aws_db_snapshot" "this" {
  db_instance_identifier = var.DB_INSTANCE_IDENTIFIER
  db_snapshot_identifier = "${var.DB_INSTANCE_IDENTIFIER}-${formatdate("YYYYMMDD-hhmmss", timestamp())}-${var.SNAPSHOT_NAME_SUFFIX}"

  tags = {
    Name      = "t9-ops-${var.DB_INSTANCE_IDENTIFIER}"
    CreatedBy = "tensor9-ops-cmd"
    Purpose   = var.SNAPSHOT_NAME_SUFFIX
  }
}

output "snapshot_identifier" {
  value = aws_db_snapshot.this.db_snapshot_identifier
}

output "snapshot_arn" {
  value = aws_db_snapshot.this.db_snapshot_arn
}

output "snapshot_status" {
  value = aws_db_snapshot.this.status
}
