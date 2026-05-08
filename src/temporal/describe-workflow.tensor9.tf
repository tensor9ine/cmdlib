terraform {
  required_providers {
    tensor9 = { source = "tensor9/tensor9" }
    null    = { source = "hashicorp/null" }
  }
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

variable "WORKFLOW_ID" {
  type        = string
  description = "Workflow ID to describe"
  validation {
    condition     = can(regex("^[a-zA-Z0-9_.-]+$", var.WORKFLOW_ID))
    error_message = "WORKFLOW_ID must contain only alphanumerics, underscore, dot, or hyphen"
  }
}

variable "RUN_ID" {
  type        = string
  default     = ""
  description = "Optional run ID (UUID); empty means latest run"
  validation {
    condition     = can(regex("^([a-f0-9-]{36})?$", var.RUN_ID))
    error_message = "RUN_ID must be empty or a 36-char UUID"
  }
}

resource "tensor9_command" "this" {
  name        = "describe-workflow"
  display     = "Describe workflow"
  description = "Fetch the full execution history summary for a single workflow — pending activities, last event, retry attempts, current state. The go-to drill-down once a workflow ID has been identified as suspect."
  icon        = "search"
  data_access = ["Workflows"]
}

resource "null_resource" "describe" {
  triggers = {
    namespace   = var.NAMESPACE
    workflow_id = var.WORKFLOW_ID
    run_id      = var.RUN_ID
    run_at      = timestamp()
  }
  provisioner "local-exec" {
    command = "tctl --namespace ${var.NAMESPACE} workflow describe --workflow_id ${var.WORKFLOW_ID}${var.RUN_ID == "" ? "" : " --run_id ${var.RUN_ID}"}"
  }
}
