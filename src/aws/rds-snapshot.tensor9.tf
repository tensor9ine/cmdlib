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
  example_output = <<-EOT
    Created RDS snapshot acme-prod-db-20260725-143012-ad-hoc from instance acme-prod-db.

    DBSnapshotIdentifier  acme-prod-db-20260725-143012-ad-hoc
    DBInstanceIdentifier  acme-prod-db
    Engine                postgres 15.7
    Status                available
    SnapshotType          manual
    AllocatedStorage      200 GiB
    SnapshotCreateTime    2026-07-25T14:30:12Z

    snapshot_identifier = acme-prod-db-20260725-143012-ad-hoc
    snapshot_arn        = arn:aws:rds:us-east-1:123456789012:snapshot:acme-prod-db-20260725-143012-ad-hoc
    snapshot_status     = available
  EOT
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
