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
  example_output = <<-EOT
    Netid State  Recv-Q Send-Q Local Address:Port  Peer Address:Port Process
    tcp   LISTEN 0      128    0.0.0.0:22          0.0.0.0:*         users:(("sshd",pid=934,fd=3))
    tcp   LISTEN 0      511    0.0.0.0:80          0.0.0.0:*         users:(("nginx",pid=2189,fd=6),("nginx",pid=2188,fd=6),("nginx",pid=2184,fd=6))
    tcp   LISTEN 0      511    0.0.0.0:443         0.0.0.0:*         users:(("nginx",pid=2189,fd=8),("nginx",pid=2188,fd=8),("nginx",pid=2184,fd=8))
    tcp   LISTEN 0      511    127.0.0.1:3000      0.0.0.0:*         users:(("node",pid=3187,fd=19))
    tcp   LISTEN 0      244    127.0.0.1:5432      0.0.0.0:*         users:(("postgres",pid=2490,fd=7))
    tcp   LISTEN 0      4096   127.0.0.1:9099      0.0.0.0:*         users:(("tensor9-applia",pid=4471,fd=8))
    tcp   LISTEN 0      4096   127.0.0.1:9100      0.0.0.0:*         users:(("tensor9-applia",pid=4471,fd=11))
    tcp   LISTEN 0      128    [::]:22             [::]:*           users:(("sshd",pid=934,fd=4))
  EOT
}

resource "null_resource" "ss" {
  triggers = {
    state = var.STATE
  }
  provisioner "local-exec" {
    command = var.STATE == "all" ? "ss -tunap" : "ss -tunap state ${lower(var.STATE)}"
  }
}
