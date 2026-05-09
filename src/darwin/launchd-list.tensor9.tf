terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = ">= 2.41.0" }
    null    = { source = "hashicorp/null" }
  }
}

provider "tensor9" {
  mode = "ops"
}

variable "FILTER" {
  type        = string
  default     = ""
  description = "Substring filter applied to launchd labels (e.g. 'tensor9' or 'com.apple'). Empty = list all."
}

resource "tensor9_command" "this" {
  name        = "launchd-list"
  display     = "Launchd services"
  description = "List launchd jobs (launchctl list), optionally filtered by label substring. Read-only."
  icon        = "list"
  data_access = ["Infrastructure"]
}

resource "null_resource" "launchd" {
  triggers = {
    filter = var.FILTER
    run_at = timestamp()
  }
  provisioner "local-exec" {
    # Output columns: PID, Status, Label. PID is `-` when not running;
    # Status is the last exit code (or `-` for "never run").
    command = var.FILTER == "" ? "launchctl list" : "launchctl list | awk 'NR==1 || /${var.FILTER}/'"
  }
}
