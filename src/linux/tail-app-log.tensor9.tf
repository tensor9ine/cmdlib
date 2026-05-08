terraform {
  required_providers {
    tensor9 = { source = "tensor9/tensor9" }
    null    = { source = "hashicorp/null" }
  }
}

variable "LINES" {
  type        = number
  default     = 200
  description = "Number of trailing lines to read"
  validation {
    condition     = var.LINES >= 1 && var.LINES <= 10000
    error_message = "LINES must be between 1 and 10000"
  }
}

variable "LOG_PATH" {
  type        = string
  default     = "/var/log/app/current.log"
  description = "Absolute path to a log file under /var/log/"
  validation {
    condition     = startswith(var.LOG_PATH, "/var/log/")
    error_message = "LOG_PATH must be inside /var/log/"
  }
}

resource "tensor9_command" "this" {
  name        = "tail-app-log"
  display     = "Tail app log"
  description = "Read the last LINES of an on-host log file under /var/log/. Read-only diagnostics — no mutation."
  icon        = "logs"
  data_access = ["Logs"]
}

resource "null_resource" "tail" {
  triggers = {
    log_path = var.LOG_PATH
    lines    = var.LINES
    run_at   = timestamp()
  }
  provisioner "local-exec" {
    command = "tail -n ${var.LINES} ${var.LOG_PATH}"
  }
}
