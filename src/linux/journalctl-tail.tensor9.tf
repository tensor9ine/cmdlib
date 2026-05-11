terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = "~> 2.41" }
    null       = { source = "hashicorp/null", version = "~> 3.2" }
  }
}

provider "tensor9" {
  mode = "ops"
}

variable "UNIT" {
  type        = string
  description = "systemd unit name (e.g. nginx.service)"
  validation {
    condition     = can(regex("^[a-zA-Z0-9_.@-]+$", var.UNIT))
    error_message = "UNIT must contain only letters, digits, and the characters _ . @ -"
  }
}

variable "LINES" {
  type        = number
  default     = 200
  description = "Number of trailing journal lines to read"
  validation {
    condition     = var.LINES >= 1 && var.LINES <= 10000
    error_message = "LINES must be between 1 and 10000"
  }
}

variable "SINCE" {
  type        = string
  default     = "1 hour ago"
  description = "journalctl --since expression (e.g. '1 hour ago', '2026-05-08 09:00')"
  validation {
    condition     = can(regex("^[a-zA-Z0-9 ,:-]+$", var.SINCE))
    error_message = "SINCE may contain only letters, digits, spaces, commas, colons, and hyphens"
  }
}

resource "tensor9_command" "this" {
  name        = "journalctl-tail"
  display     = "Journalctl tail"
  description = "Tail recent journal entries for a systemd unit. Read-only."
  icon        = "logs"
  data_access = ["Logs"]
}

resource "null_resource" "journal" {
  triggers = {
    unit   = var.UNIT
    lines  = var.LINES
    since  = var.SINCE
  }
  provisioner "local-exec" {
    command = "journalctl -u ${var.UNIT} --no-pager --since \"${var.SINCE}\" -n ${var.LINES}"
  }
}
