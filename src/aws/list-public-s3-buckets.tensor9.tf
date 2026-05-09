terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = ">= 2.40.0" }
    aws     = { source = "hashicorp/aws" }
  }
}

variable "REGION" {
  type        = string
  default     = "us-east-1"
  description = "AWS region for the provider (S3 listing is global, but the SDK still needs a region pinned)"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.REGION))
    error_message = "REGION must be a valid AWS region identifier"
  }
}

provider "aws" {
  region = var.REGION
}

resource "tensor9_command" "this" {
  name        = "list-public-s3-buckets"
  display     = "List public S3 buckets"
  description = "Diagnostic: list S3 buckets in this account whose ACL grants READ or WRITE to AllUsers / AuthenticatedUsers. Read-only."
  icon        = "search"
  data_access = ["Infrastructure"]
}

data "aws_s3_buckets" "all" {}

data "aws_s3_bucket_acl" "by_bucket" {
  for_each = toset(data.aws_s3_buckets.all.buckets[*].name)
  bucket   = each.value
}

locals {
  public_uris = [
    "http://acs.amazonaws.com/groups/global/AllUsers",
    "http://acs.amazonaws.com/groups/global/AuthenticatedUsers",
  ]

  public_buckets = [
    for name in data.aws_s3_buckets.all.buckets[*].name : {
      bucket = name
      grants = [
        for g in data.aws_s3_bucket_acl.by_bucket[name].access_control_policy[0].grants : {
          permission = g.permission
          grantee    = try(g.grantee[0].uri, "")
        }
        if try(contains(local.public_uris, g.grantee[0].uri), false)
      ]
    }
    if length([
      for g in data.aws_s3_bucket_acl.by_bucket[name].access_control_policy[0].grants :
      g if try(contains(local.public_uris, g.grantee[0].uri), false)
    ]) > 0
  ]
}

output "public_buckets" {
  value = local.public_buckets
}

output "public_bucket_count" {
  value = length(local.public_buckets)
}
