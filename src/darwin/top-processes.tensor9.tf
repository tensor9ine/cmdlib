terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = "~> 2.41" }
    null    = { source = "hashicorp/null", version = "~> 3.2" }
  }
}

provider "tensor9" {
  mode = "ops"
}

variable "SORT_BY" {
  type        = string
  default     = "cpu"
  description = "Sort key for the process list: cpu | mem"
  validation {
    condition     = contains(["cpu", "mem"], var.SORT_BY)
    error_message = "SORT_BY must be cpu or mem"
  }
}

variable "LIMIT" {
  type        = number
  default     = 20
  description = "Maximum number of processes to show (1-100)"
  validation {
    condition     = var.LIMIT >= 1 && var.LIMIT <= 100
    error_message = "LIMIT must be between 1 and 100"
  }
}

resource "tensor9_command" "this" {
  name        = "top-processes"
  display     = "Top processes"
  description = "Snapshot the busiest processes on the host (top -l 1), sorted by CPU or memory. Read-only."
  icon        = "activity"
  data_access = ["Infrastructure"]
}

resource "null_resource" "top" {
  triggers = {
    sort_by = var.SORT_BY
    limit   = var.LIMIT
  }
  provisioner "local-exec" {
    # `top -l 1` takes a single sample then exits — much friendlier
    # for a one-shot ops cmd than the curses-driven default.
    command = "top -l 1 -o ${var.SORT_BY} -n ${var.LIMIT} -stats pid,user,cpu,mem,command"
  }
}
