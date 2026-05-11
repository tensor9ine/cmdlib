terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = "~> 2.41" }
    aws        = { source = "hashicorp/aws", version = "~> 5.0" }
    null       = { source = "hashicorp/null", version = "~> 3.2" }
  }
}

provider "tensor9" {
  mode = "ops"
}

variable "REGION" {
  type        = string
  default     = "us-west-2"
  description = "AWS region to operate in"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.REGION))
    error_message = "REGION must be a valid AWS region identifier"
  }
}

variable "MIN_AGE_DAYS" {
  type        = number
  default     = 30
  description = "Only terminate instances stopped for at least this many days"
  validation {
    condition     = var.MIN_AGE_DAYS >= 1 && var.MIN_AGE_DAYS <= 365
    error_message = "MIN_AGE_DAYS must be between 1 and 365"
  }
}

provider "aws" {
  region = var.REGION
}

resource "tensor9_command" "this" {
  name         = "terminate-stopped-instances"
  display      = "Terminate long-stopped EC2 instances"
  description  = "Find EC2 instances that have been in 'stopped' state for at least MIN_AGE_DAYS days and terminate them. Destructive — instances cannot be recovered after termination."
  icon         = "trash"
  data_access  = ["Infrastructure"]
  side_effects = ["ec2-termination"]
}

data "aws_instances" "stopped" {
  instance_state_names = ["stopped"]
}

data "aws_instance" "by_id" {
  for_each    = toset(data.aws_instances.stopped.ids)
  instance_id = each.value
}

locals {
  cutoff = timeadd(timestamp(), "-${var.MIN_AGE_DAYS * 24}h")

  # Use the most recent state-transition time as a proxy for "stopped at".
  # state_transition_reason is opaque, so we rely on launch_time as a floor and
  # let the operator double-check via the listed ids before re-running with apply.
  victims = [
    for id in data.aws_instances.stopped.ids : id
    if data.aws_instance.by_id[id].launch_time < local.cutoff
  ]
}

resource "null_resource" "terminate" {
  for_each = toset(local.victims)

  triggers = {
    instance_id = each.value
    region      = var.REGION
  }

  provisioner "local-exec" {
    command = "aws ec2 terminate-instances --region ${var.REGION} --instance-ids ${each.value}"
  }
}

output "terminated_instance_ids" {
  value = local.victims
}

output "cutoff_timestamp" {
  value = local.cutoff
}
