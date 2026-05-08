terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9" }
    null    = { source = "hashicorp/null" }
  }
}

variable "SORT_BY" {
  type        = string
  default     = "cpu"
  description = "Which resource to sort processes by: cpu or memory"
  validation {
    condition     = can(regex("^(cpu|memory)$", var.SORT_BY))
    error_message = "SORT_BY must be 'cpu' or 'memory'"
  }
}

variable "LIMIT" {
  type        = number
  default     = 20
  description = "Number of top processes to display"
  validation {
    condition     = var.LIMIT >= 1 && var.LIMIT <= 100
    error_message = "LIMIT must be between 1 and 100"
  }
}

resource "tensor9_command" "this" {
  name        = "top-processes"
  display     = "Top processes"
  description = "List the top LIMIT processes on the host sorted by CPU or memory. Read-only."
  icon        = "activity"
  data_access = ["Infrastructure"]
}

resource "null_resource" "top" {
  triggers = {
    sort_by = var.SORT_BY
    limit   = var.LIMIT
    run_at  = timestamp()
  }
  provisioner "local-exec" {
    command = "ps -eo pid,user,pcpu,pmem,comm --sort=-${var.SORT_BY == "cpu" ? "pcpu" : "pmem"} | head -n ${var.LIMIT + 1}"
  }
}
