terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = "~> 2.41" }
    null    = { source = "hashicorp/null", version = "~> 3.2" }
  }
}

provider "tensor9" {
  mode = "ops"
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
  data_access = ["Network"]
}

resource "null_resource" "ss" {
  triggers = {
    state = var.STATE
  }
  provisioner "local-exec" {
    command = var.STATE == "all" ? "ss -tunap" : "ss -tunap state ${lower(var.STATE)}"
  }
}
