terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = "~> 2.41" }
    null    = { source = "hashicorp/null", version = "~> 3.2" }
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
  example_output = <<-EOT
    COMMAND    PID      USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
    launchd      1      root    8u  IPv4 0x9a1f2c3d4e5f6071      0t0  TCP *:22 (LISTEN)
    tensor9-a  832   tensor9    7u  IPv4 0x1122334455667788      0t0  TCP 127.0.0.1:8443 (LISTEN)
    tensor9-a  832   tensor9   14u  IPv4 0x8877665544332211      0t0  TCP 10.0.1.42:52210->34.117.59.81:8443 (ESTABLISHED)
    postgres   998 _postgres    6u  IPv6 0xa0b1c2d3e4f50617      0t0  TCP [::1]:5432 (LISTEN)
    postgres   998 _postgres    7u  IPv4 0x0f1e2d3c4b5a6978      0t0  TCP 127.0.0.1:5432 (LISTEN)
    node      1204   tensor9   22u  IPv6 0x1a2b3c4d5e6f7081      0t0  TCP *:3000 (LISTEN)
    node      1204   tensor9   35u  IPv4 0x718293a4b5c6d7e8      0t0  TCP 10.0.1.42:3000->10.0.1.7:52344 (ESTABLISHED)
  EOT
}

resource "null_resource" "lsof" {
  triggers = {
    proto = var.PROTO
  }
  provisioner "local-exec" {
    # `-i` lists internet sockets; `-n` skips DNS; `-P` keeps numeric
    # port numbers. `-iTCP` / `-iUDP` narrow further when requested.
    command = var.PROTO == "both" ? "lsof -i -n -P" : "lsof -i${upper(var.PROTO)} -n -P"
  }
}
