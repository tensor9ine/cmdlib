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
  data_access = ["CustomResources"]
  example_output = <<-EOT
    Execution Info:
      WorkflowId     order-8f31c2a9
      RunId          01912f3a-6b7c-4d2e-9a1b-0c3d4e5f6a7b
      Type           OrderWorkflow
      Namespace      default
      TaskQueue      orders
      Status         Running
      HistoryLength  47
      StartTime      2026-07-25T14:02:11Z
      CloseTime      <nil>

    Pending Activities:
      ActivityId    ActivityType    State       Attempt  MaximumAttempts  LastFailure
      3             ChargeCard      Started     4        10               activity error (type: ChargeCard): 503 payment-gateway unavailable

    Recent Events:
      6   WorkflowTaskCompleted     2026-07-25T14:02:13Z
      7   ActivityTaskScheduled     2026-07-25T14:02:13Z  ReserveInventory
      8   ActivityTaskCompleted     2026-07-25T14:02:15Z
      9   ActivityTaskScheduled     2026-07-25T14:02:15Z  ChargeCard
      10  ActivityTaskStarted       2026-07-25T14:02:15Z  attempt 1
      11  ActivityTaskFailed        2026-07-25T14:04:31Z  503 payment-gateway unavailable (will retry)
  EOT
}

resource "null_resource" "describe" {
  triggers = {
    namespace   = var.NAMESPACE
    workflow_id = var.WORKFLOW_ID
    run_id      = var.RUN_ID
  }
  provisioner "local-exec" {
    command = "tctl --namespace ${var.NAMESPACE} workflow describe --workflow_id ${var.WORKFLOW_ID}${var.RUN_ID == "" ? "" : " --run_id ${var.RUN_ID}"}"
  }
}
