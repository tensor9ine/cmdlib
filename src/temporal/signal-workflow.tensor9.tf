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

variable "WORKFLOW_ID" {
  type        = string
  description = "Workflow ID to signal"
  validation {
    condition     = can(regex("^[a-zA-Z0-9_.-]+$", var.WORKFLOW_ID))
    error_message = "WORKFLOW_ID must contain only alphanumerics, underscore, dot, or hyphen"
  }
}

variable "SIGNAL_NAME" {
  type        = string
  description = "Name of the signal handler to invoke (must match the running workflow's @SignalMethod)"
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.SIGNAL_NAME))
    error_message = "SIGNAL_NAME must start with a letter and contain only alphanumerics or underscore"
  }
}

variable "INPUT_JSON" {
  type        = string
  default     = "{}"
  description = "JSON-encoded signal payload"
  validation {
    condition     = can(jsondecode(var.INPUT_JSON))
    error_message = "INPUT_JSON must be valid JSON"
  }
}

resource "tensor9_command" "this" {
  name         = "signal-workflow"
  display      = "Signal workflow"
  description  = "Deliver a named signal with a JSON payload to a running workflow. Used for nudging a workflow forward (e.g. injecting an approval, releasing a wait condition) without restarting it."
  icon         = "play"
  data_access  = ["CustomResources"]
  side_effects = ["workflow-signaled"]
  example_output = <<-EOT
    Signal workflow succeeded.

    Namespace   default
    WorkflowId  order-8f31c2a9
    RunId       01912f3a-6b7c-4d2e-9a1b-0c3d4e5f6a7b
    Signal      approvePayment
    Input       {}

    The signal was recorded in workflow history as WorkflowExecutionSignaled (eventId 48).
  EOT
}

resource "null_resource" "signal" {
  triggers = {
    namespace   = var.NAMESPACE
    workflow_id = var.WORKFLOW_ID
    signal_name = var.SIGNAL_NAME
    input_json  = var.INPUT_JSON
  }
  provisioner "local-exec" {
    command = "tctl --namespace ${var.NAMESPACE} workflow signal --workflow_id ${var.WORKFLOW_ID} --name ${var.SIGNAL_NAME} --input '${var.INPUT_JSON}'"
  }
}
