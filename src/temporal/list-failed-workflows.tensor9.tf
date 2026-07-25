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
  example_output = <<-EOT
    WorkflowId      RunId                                 Type           Status      StartTime
    order-9a72be4f  01912ef0-5a6b-4c7d-8e9f-0a1b2c3d4e5f  OrderWorkflow  Failed      2026-07-25T09:14:22Z
    order-1c58fa30  01912ef1-6b7c-4d8e-9f0a-1b2c3d4e5f60  OrderWorkflow  TimedOut    2026-07-25T10:41:07Z
    order-b6e3d91c  01912ef2-7c8d-4e9f-a01b-2c3d4e5f6071  OrderWorkflow  Terminated  2026-07-25T11:58:36Z
    order-4f0a2d77  01912ef3-8d9e-4f0a-b12c-3d4e5f607182  OrderWorkflow  Failed      2026-07-25T12:33:49Z

    4 workflows in namespace default over the last 24h (task queue orders)
  EOT
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
