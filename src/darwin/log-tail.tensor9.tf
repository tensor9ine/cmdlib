terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = "~> 2.41" }
    null    = { source = "hashicorp/null", version = "~> 3.2" }
  }
}

provider "tensor9" {
  mode = "ops"
}

variable "WINDOW" {
  type        = string
  default     = "5m"
  description = "Lookback window for log show (e.g. 1m, 5m, 1h, 1d)"
  validation {
    condition     = can(regex("^[0-9]+(s|m|h|d)$", var.WINDOW))
    error_message = "WINDOW must be a number followed by s, m, h, or d"
  }
}

variable "PREDICATE" {
  type        = string
  default     = ""
  description = "Optional log show predicate (e.g. 'process == \"kernel\"' or 'subsystem == \"com.apple.network\"'). Empty = all events."
}

resource "tensor9_command" "this" {
  name        = "log-tail"
  display     = "Recent system logs"
  description = "Tail unified-logging events from the last WINDOW (replaces dmesg/journalctl on macOS). Read-only."
  icon        = "file-text"
  data_access = ["Logs"]
}

resource "null_resource" "log_show" {
  triggers = {
    window    = var.WINDOW
    predicate = var.PREDICATE
  }
  provisioner "local-exec" {
    # `log show --style compact` strips the verbose default columns;
    # the predicate slot lets the operator narrow when needed.
    command = var.PREDICATE == "" ? "log show --style compact --last ${var.WINDOW}" : "log show --style compact --last ${var.WINDOW} --predicate '${var.PREDICATE}'"
  }
}
