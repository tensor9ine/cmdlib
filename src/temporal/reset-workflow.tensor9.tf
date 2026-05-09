terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = ">= 2.41.0" }
    null    = { source = "hashicorp/null" }
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

variable "WORKFLOW_ID" {
  type        = string
  description = "Workflow ID to reset"
  validation {
    condition     = can(regex("^[a-zA-Z0-9_.-]+$", var.WORKFLOW_ID))
    error_message = "WORKFLOW_ID must contain only alphanumerics, underscore, dot, or hyphen"
  }
}

variable "EVENT_ID" {
  type        = string
  description = "Event ID to reset to (positive integer; usually the last good WorkflowTaskCompleted before a poisoned activity)"
  validation {
    condition     = can(regex("^[0-9]+$", var.EVENT_ID)) && tonumber(var.EVENT_ID) > 0
    error_message = "EVENT_ID must be a positive integer"
  }
}

variable "REASON" {
  type        = string
  default     = "operator-reset"
  description = "Free-form reason recorded in workflow history"
  validation {
    condition     = can(regex("^[a-zA-Z0-9 ,.-]+$", var.REASON))
    error_message = "REASON must contain only alphanumerics, spaces, commas, periods, or hyphens"
  }
}

resource "tensor9_command" "this" {
  name         = "reset-workflow"
  display      = "Reset workflow"
  description  = "Rewind a workflow to a prior event ID and restart execution from there. Standard recovery for a workflow that failed at a specific activity once that activity is fixed — re-uses the original WorkflowID."
  icon         = "refresh"
  data_access  = ["Workflows"]
  side_effects = ["workflow-reset"]
}

resource "null_resource" "reset" {
  triggers = {
    namespace   = var.NAMESPACE
    workflow_id = var.WORKFLOW_ID
    event_id    = var.EVENT_ID
    reason      = var.REASON
    run_at      = timestamp()
  }
  provisioner "local-exec" {
    command = "tctl --namespace ${var.NAMESPACE} workflow reset --workflow_id ${var.WORKFLOW_ID} --event_id ${var.EVENT_ID} --reason '${var.REASON}'"
  }
}
