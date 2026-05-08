terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9" }
    null    = { source = "hashicorp/null" }
  }
}

variable "STATE" {
  type        = string
  default     = "LISTEN"
  description = "Socket state filter: LISTEN, ESTABLISHED, or all"
  validation {
    condition     = can(regex("^(LISTEN|ESTABLISHED|all)$", var.STATE))
    error_message = "STATE must be one of LISTEN, ESTABLISHED, all"
  }
}

resource "tensor9_command" "this" {
  name        = "network-connections"
  display     = "Network connections"
  description = "List open TCP/UDP sockets on the host (ss -tunap), optionally filtered by state. Read-only."
  icon        = "network"
  data_access = ["Networking"]
}

resource "null_resource" "ss" {
  triggers = {
    state  = var.STATE
    run_at = timestamp()
  }
  provisioner "local-exec" {
    command = var.STATE == "all" ? "ss -tunap" : "ss -tunap state ${lower(var.STATE)}"
  }
}
