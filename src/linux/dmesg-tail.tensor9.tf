terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = ">= 2.41.0" }
    null    = { source = "hashicorp/null" }
  }
}

provider "tensor9" {
  mode = "ops"
}

variable "LINES" {
  type        = number
  default     = 100
  description = "Number of trailing kernel ring buffer lines to read"
  validation {
    condition     = var.LINES >= 1 && var.LINES <= 1000
    error_message = "LINES must be between 1 and 1000"
  }
}

resource "tensor9_command" "this" {
  name        = "dmesg-tail"
  display     = "Dmesg tail"
  description = "Read the last LINES from the kernel ring buffer (dmesg). Read-only."
  icon        = "logs"
  data_access = ["Logs"]
}

resource "null_resource" "dmesg" {
  triggers = {
    lines  = var.LINES
    run_at = timestamp()
  }
  provisioner "local-exec" {
    command = "dmesg --ctime | tail -n ${var.LINES}"
  }
}
