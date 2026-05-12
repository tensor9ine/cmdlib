terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = "~> 2.41" }
    null    = { source = "hashicorp/null", version = "~> 3.2" }
  }
}

provider "tensor9" {
  mode = "ops"
}

variable "NAMESPACE" {
  type        = string
  default     = "default"
  description = "Temporal namespace"
  validation {
    condition     = can(regex("^[a-zA-Z0-9_.-]+$", var.NAMESPACE))
    error_message = "NAMESPACE must contain only alphanumerics, underscore, dot, or hyphen"
  }
}

variable "HOURS" {
  type        = number
  default     = 24
  description = "Look back window in hours (1..720, i.e. up to 30 days)"
  validation {
    condition     = var.HOURS >= 1 && var.HOURS <= 720
    error_message = "HOURS must be between 1 and 720"
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
  name        = "list-failed-workflows"
  display     = "List failed workflows"
  description = "Diagnostic: list workflows that ended in Failed, TimedOut, or Terminated state within the last HOURS. Starting point for post-incident review or batch reset."
  icon        = "alert"
  data_access = ["CustomResources"]
}

resource "null_resource" "list" {
  triggers = {
    namespace = var.NAMESPACE
    hours     = var.HOURS
    limit     = var.LIMIT
  }
  provisioner "local-exec" {
    command = "tctl --namespace ${var.NAMESPACE} workflow list --query 'ExecutionStatus IN (\"Failed\", \"TimedOut\", \"Terminated\") AND StartTime > \"-${var.HOURS}h\"' --pagesize ${var.LIMIT}"
  }
}
