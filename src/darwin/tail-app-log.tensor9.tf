terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = "~> 2.41" }
    null       = { source = "hashicorp/null", version = "~> 3.2" }
  }
}

provider "tensor9" {
  mode = "ops"
}

variable "PATH" {
  type        = string
  description = "Absolute path to the log file to tail. Must live under /Library/Logs, /var/log, /tmp, or the user's ~/Library/Logs."
  validation {
    condition = (
      startswith(var.PATH, "/Library/Logs/") ||
      startswith(var.PATH, "/var/log/") ||
      startswith(var.PATH, "/tmp/") ||
      can(regex("^/Users/[^/]+/Library/Logs/", var.PATH))
    )
    error_message = "PATH must live under /Library/Logs, /var/log, /tmp, or ~/Library/Logs"
  }
}

variable "LINES" {
  type        = number
  default     = 200
  description = "Number of trailing lines to show (1-2000)"
  validation {
    condition     = var.LINES >= 1 && var.LINES <= 2000
    error_message = "LINES must be between 1 and 2000"
  }
}

resource "tensor9_command" "this" {
  name        = "tail-app-log"
  display     = "Tail app log"
  description = "Snapshot the last LINES of an application log file under the allowed log roots. Read-only."
  icon        = "file-text"
  data_access = ["Logs"]
}

resource "null_resource" "tail" {
  triggers = {
    path   = var.PATH
    lines  = var.LINES
  }
  provisioner "local-exec" {
    command = "tail -n ${var.LINES} '${var.PATH}'"
  }
}
