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

# aws-provider 6.x removed `aws_s3_buckets` (plural list) and
# `aws_s3_bucket_acl` data sources; fall back to the AWS CLI via
# local-exec. `s3api list-buckets` + `get-bucket-acl` are the same
# read-only calls those data sources used to wrap — just returned on
# stdout instead of as Terraform attributes.
resource "null_resource" "scan" {
  triggers = {
    region = var.REGION
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      buckets=$(aws s3api list-buckets --query 'Buckets[].Name' --output text --region ${var.REGION})
      printf 'bucket\tpermission\tgrantee\n'
      for b in $buckets; do
        aws s3api get-bucket-acl --bucket "$b" --region ${var.REGION} \
          --query 'Grants[?Grantee.URI==`http://acs.amazonaws.com/groups/global/AllUsers` || Grantee.URI==`http://acs.amazonaws.com/groups/global/AuthenticatedUsers`].[Permission,Grantee.URI]' \
          --output text 2>/dev/null \
          | awk -v b="$b" 'NF { printf "%s\t%s\t%s\n", b, $1, $2 }' || true
      done
    EOT
  }
}
