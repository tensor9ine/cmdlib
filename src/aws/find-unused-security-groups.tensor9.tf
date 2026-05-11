terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = "~> 2.41" }
    aws        = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "tensor9" {
  mode = "ops"
}

variable "REGION" {
  type        = string
  default     = "us-west-2"
  description = "AWS region to scan"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.REGION))
    error_message = "REGION must be a valid AWS region identifier"
  }
}

provider "aws" {
  region = var.REGION
}

resource "tensor9_command" "this" {
  name        = "find-unused-security-groups"
  display     = "Find unused security groups"
  description = "List security groups in REGION that are not attached to any ENI — input for SG-cleanup audits. Read-only."
  icon        = "search"
  data_access = ["Infrastructure"]
}

data "aws_security_groups" "all" {}

data "aws_security_group" "by_id" {
  for_each = toset(data.aws_security_groups.all.ids)
  id       = each.value
}

# An ENI references its SGs via the "group-id" attribute.
data "aws_network_interfaces" "by_sg" {
  for_each = toset(data.aws_security_groups.all.ids)

  filter {
    name   = "group-id"
    values = [each.value]
  }
}

locals {
  unused_sg_ids = [
    for id in data.aws_security_groups.all.ids : id
    if length(data.aws_network_interfaces.by_sg[id].ids) == 0
       && data.aws_security_group.by_id[id].name != "default"
  ]
}

output "unused_security_groups" {
  value = [
    for id in local.unused_sg_ids : {
      group_id    = id
      name        = data.aws_security_group.by_id[id].name
      vpc_id      = data.aws_security_group.by_id[id].vpc_id
      description = data.aws_security_group.by_id[id].description
    }
  ]
}

output "unused_count" {
  value = length(local.unused_sg_ids)
}
