terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = "~> 2.41" }
    null       = { source = "hashicorp/null", version = "~> 3.2" }
  }
}

provider "tensor9" {
  mode = "ops"
}

variable "NAMESPACE" {
  type        = string
  default     = "default"
  description = "Temporal namespace to query"
  validation {
    condition     = can(regex("^[a-zA-Z0-9_.-]+$", var.NAMESPACE))
    error_message = "NAMESPACE must contain only alphanumerics, underscore, dot, or hyphen"
  }
}

variable "LIMIT" {
  type        = number
  default     = 100
  description = "Maximum number of workflows to return per page"
  validation {
    condition     = var.LIMIT >= 1 && var.LIMIT <= 1000
    error_message = "LIMIT must be between 1 and 1000"
  }
}

resource "tensor9_command" "this" {
  name        = "list-running-workflows"
  display     = "List running workflows"
  description = "Enumerate workflows currently in the Running state in the given Temporal namespace. First-line check when triaging a stuck pipeline or unexpected throughput dip."
  icon        = "search"
  data_access = ["CustomResources"]
}

resource "null_resource" "list" {
  triggers = {
    namespace = var.NAMESPACE
    limit     = var.LIMIT
  }
  provisioner "local-exec" {
    command = "tctl --namespace ${var.NAMESPACE} workflow list --query 'ExecutionStatus=\"Running\"' --pagesize ${var.LIMIT}"
  }
}
