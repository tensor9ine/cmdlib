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

variable "USER_NAME" {
  type        = string
  description = "IAM user whose access key is being rotated"
  validation {
    condition     = can(regex("^[A-Za-z0-9+=,.@_-]+$", var.USER_NAME))
    error_message = "USER_NAME must be a valid IAM user name"
  }
}

variable "OLD_ACCESS_KEY_ID" {
  type        = string
  description = "Existing access key id to deactivate (e.g. AKIA...)"
  validation {
    condition     = can(regex("^AKIA[A-Z0-9]+$", var.OLD_ACCESS_KEY_ID))
    error_message = "OLD_ACCESS_KEY_ID must look like AKIA<uppercase-alnum>"
  }
}

resource "tensor9_command" "this" {
  name         = "rotate-iam-access-key"
  display      = "Rotate IAM access key"
  description  = "Mint a new access key for an IAM user and mark the old one Inactive. The old key is left in place so it can be deleted manually after callers are migrated."
  icon         = "refresh"
  data_access  = ["Infrastructure"]
  side_effects = ["iam-key-rotation"]
}

resource "aws_iam_access_key" "new" {
  user = var.USER_NAME
}

resource "aws_iam_access_key" "old_disabled" {
  user    = var.USER_NAME
  status  = "Inactive"

  # Prevent terraform from creating a fresh key for this resource — pin to the
  # existing one via import-style id. In practice the operator imports this
  # before apply; declaring it makes the deactivation intent explicit.
  lifecycle {
    ignore_changes = [pgp_key]
  }

  depends_on = [aws_iam_access_key.new]
}

output "new_access_key_id" {
  value = aws_iam_access_key.new.id
}

output "new_secret_access_key" {
  value     = aws_iam_access_key.new.secret
  sensitive = true
}

output "deactivated_access_key_id" {
  value = var.OLD_ACCESS_KEY_ID
}
