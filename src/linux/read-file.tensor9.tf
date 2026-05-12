terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = "~> 2.41" }
    null    = { source = "hashicorp/null", version = "~> 3.2" }
  }
}

provider "tensor9" {
  mode = "ops"
}

variable "FILE_PATH" {
  type        = string
  description = "Absolute path to a file to read on the appliance host."
}

variable "MAX_BYTES" {
  type        = number
  default     = 1048576
  description = "Cap on bytes read (1 KiB to 10 MiB). Default 1 MiB."
  validation {
    condition     = var.MAX_BYTES >= 1024 && var.MAX_BYTES <= 10485760
    error_message = "MAX_BYTES must be between 1024 (1 KiB) and 10485760 (10 MiB)."
  }
}

resource "tensor9_command" "this" {
  name        = "read-file"
  display     = "Read file"
  description = "Read a particular file from the appliance host (capped at MAX_BYTES). Caller chooses the path; the buyer narrows via per-variable constraint at approval time. Read-only."
  icon        = "file-text"
  data_access = ["Logs", "Infrastructure"]
}

resource "null_resource" "read" {
  triggers = {
    file_path = var.FILE_PATH
    max_bytes = var.MAX_BYTES
  }
  provisioner "local-exec" {
    command = "head -c ${var.MAX_BYTES} '${var.FILE_PATH}'"
  }
}
