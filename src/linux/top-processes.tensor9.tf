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
  example_output = <<-EOT
        PID USER       %CPU %MEM COMMAND
       3187 node       12.4  3.1 node
       3201 node        9.8  2.9 node
       2490 postgres    6.1  4.7 postgres
       2517 postgres    4.3  1.2 postgres
       2184 root        2.1  0.2 nginx
       2188 nginx       1.7  0.3 nginx
       2189 nginx       1.5  0.3 nginx
       1122 root        1.2  0.6 dockerd
       1098 root        0.9  0.4 containerd
       4471 tensor9     0.7  0.2 tensor9-applianc
       2492 postgres    0.5  3.9 postgres
       2491 postgres    0.4  0.8 postgres
        892 root        0.3  0.1 systemd-journal
          1 root        0.2  0.1 systemd
        934 root        0.2  0.1 sshd
       2493 postgres    0.1  0.5 postgres
       3402 root        0.1  0.1 containerd-shim
       1201 root        0.0  0.1 amazon-ssm-agen
        701 chrony      0.0  0.0 chronyd
        955 root        0.0  0.1 crond
  EOT
}

resource "null_resource" "top" {
  triggers = {
    sort_by = var.SORT_BY
    limit   = var.LIMIT
  }
  provisioner "local-exec" {
    command = "ps -eo pid,user,pcpu,pmem,comm --sort=-${var.SORT_BY == "cpu" ? "pcpu" : "pmem"} | head -n ${var.LIMIT + 1}"
  }
}
