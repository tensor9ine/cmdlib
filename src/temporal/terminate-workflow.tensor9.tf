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
  description = "Workflow ID to terminate"
  validation {
    condition     = can(regex("^[a-zA-Z0-9_.-]+$", var.WORKFLOW_ID))
    error_message = "WORKFLOW_ID must contain only alphanumerics, underscore, dot, or hyphen"
  }
}

variable "RUN_ID" {
  type        = string
  default     = ""
  description = "Optional run ID (UUID); empty terminates the latest run"
  validation {
    condition     = can(regex("^([a-f0-9-]{36})?$", var.RUN_ID))
    error_message = "RUN_ID must be empty or a 36-char UUID"
  }
}

variable "REASON" {
  type        = string
  default     = "operator-terminated"
  description = "Free-form reason recorded in workflow history"
  validation {
    condition     = can(regex("^[a-zA-Z0-9 ,.-]+$", var.REASON))
    error_message = "REASON must contain only alphanumerics, spaces, commas, periods, or hyphens"
  }
}

resource "tensor9_command" "this" {
  name         = "terminate-workflow"
  display      = "Terminate workflow"
  description  = "Forcibly end a workflow execution. Unlike cancel, this does not run cleanup handlers — use only when the workflow is wedged and cancellation will not progress. The reason is recorded in history for audit."
  icon         = "x-circle"
  data_access  = ["Workflows"]
  side_effects = ["workflow-termination"]
}

resource "null_resource" "terminate" {
  triggers = {
    namespace   = var.NAMESPACE
    workflow_id = var.WORKFLOW_ID
    run_id      = var.RUN_ID
    reason      = var.REASON
    run_at      = timestamp()
  }
  provisioner "local-exec" {
    command = "tctl --namespace ${var.NAMESPACE} workflow terminate --workflow_id ${var.WORKFLOW_ID}${var.RUN_ID == "" ? "" : " --run_id ${var.RUN_ID}"} --reason '${var.REASON}'"
  }
}
