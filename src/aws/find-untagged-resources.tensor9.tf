terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = "~> 2.41" }
    aws     = { source = "hashicorp/aws", version = "~> 6.0" }
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

variable "REQUIRED_TAG" {
  type        = string
  default     = "Owner"
  description = "Tag key every infra resource is expected to carry"
  validation {
    condition     = can(regex("^[A-Za-z0-9_.:/=+\\-@]+$", var.REQUIRED_TAG))
    error_message = "REQUIRED_TAG must be a valid AWS tag key"
  }
}

provider "aws" {
  region = var.REGION
}

resource "tensor9_command" "this" {
  name        = "find-untagged-resources"
  display     = "Find untagged AWS resources"
  description = "List EC2 instances and EBS volumes in REGION that are missing the REQUIRED_TAG key. Read-only audit input for ownership/cost-allocation reviews."
  icon        = "search"
  data_access = ["Infrastructure"]
  example_output = <<-EOT
    required_tag = Owner

    untagged_instances:
    instance_id          name
    i-0a1b2c3d4e5f6a7b8  acme-prod-web-1
    i-0b2c3d4e5f6a7b8c9

    untagged_volumes:
    volume_id              size_gib
    vol-0f1e2d3c4b5a69788  200
    vol-0a9b8c7d6e5f40312  100
  EOT
}

# All instances + volumes; we filter for "missing tag" in the output expressions
# because AWS tag-filters can only match present keys.
data "aws_instances" "all" {
  instance_state_names = ["running", "stopped", "pending", "stopping"]
}

data "aws_instance" "by_id" {
  for_each    = toset(data.aws_instances.all.ids)
  instance_id = each.value
}

data "aws_ebs_volumes" "all" {}

data "aws_ebs_volume" "by_id" {
  for_each = toset(data.aws_ebs_volumes.all.ids)
  filter {
    name   = "volume-id"
    values = [each.value]
  }
}

output "untagged_instances" {
  value = [
    for id in data.aws_instances.all.ids : {
      instance_id = id
      name        = lookup(data.aws_instance.by_id[id].tags, "Name", "")
    }
    if !contains(keys(data.aws_instance.by_id[id].tags), var.REQUIRED_TAG)
  ]
}

output "untagged_volumes" {
  value = [
    for id in data.aws_ebs_volumes.all.ids : {
      volume_id = id
      size_gib  = data.aws_ebs_volume.by_id[id].size
    }
    if !contains(keys(data.aws_ebs_volume.by_id[id].tags), var.REQUIRED_TAG)
  ]
}

output "required_tag" {
  value = var.REQUIRED_TAG
}
