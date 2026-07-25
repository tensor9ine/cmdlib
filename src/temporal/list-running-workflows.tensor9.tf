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
  example_output = <<-EOT
    WorkflowId      RunId                                 Type           Status   StartTime
    order-8f31c2a9  01912f3a-6b7c-4d2e-9a1b-0c3d4e5f6a7b  OrderWorkflow  Running  2026-07-25T14:02:11Z
    order-3d9e71bf  01912f4b-1a2b-4c3d-8e9f-1a2b3c4d5e6f  OrderWorkflow  Running  2026-07-25T14:05:47Z
    order-c40a55e2  01912f5c-2b3c-4d5e-9f0a-2b3c4d5e6f70  OrderWorkflow  Running  2026-07-25T14:09:33Z
    order-7b18ad60  01912f6d-3c4d-5e6f-a01b-3c4d5e6f7081  OrderWorkflow  Running  2026-07-25T14:12:05Z
    order-e2f4c1a8  01912f7e-4d5e-6f70-b12c-4d5e6f708192  OrderWorkflow  Running  2026-07-25T14:15:52Z

    5 workflows in namespace default (task queue orders)
  EOT
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
