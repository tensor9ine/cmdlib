terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = "~> 2.41" }
    null       = { source = "hashicorp/null", version = "~> 3.2" }
  }
}

provider "tensor9" {
  mode = "ops"
}

variable "PROTO" {
  type        = string
  default     = "tcp"
  description = "Protocol filter: tcp | udp | both"
  validation {
    condition     = contains(["tcp", "udp", "both"], var.PROTO)
    error_message = "PROTO must be tcp, udp, or both"
  }
}

resource "tensor9_command" "this" {
  name        = "network-connections"
  display     = "Network connections"
  description = "List active network sockets (lsof -i -n -P), optionally filtered by protocol. Read-only."
  icon        = "globe"
  data_access = ["Infrastructure"]
}

resource "null_resource" "lsof" {
  triggers = {
    proto  = var.PROTO
  }
  provisioner "local-exec" {
    # `-i` lists internet sockets; `-n` skips DNS; `-P` keeps numeric
    # port numbers. `-iTCP` / `-iUDP` narrow further when requested.
    command = var.PROTO == "both" ? "lsof -i -n -P" : "lsof -i${upper(var.PROTO)} -n -P"
  }
}
