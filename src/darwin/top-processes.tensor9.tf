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
  example_output = <<-EOT
    Processes: 412 total, 3 running, 409 sleeping, 1893 threads
    2026/07/25 14:33:02
    Load Avg: 2.14, 1.98, 1.76
    CPU usage: 8.42% user, 3.11% sys, 88.46% idle
    SharedLibs: 412M resident, 78M data, 42M linkedit.
    MemRegions: 98234 total, 2841M resident, 121M private, 1204M shared.
    PhysMem: 24G used (2841M wired, 1204M compressor), 7648M unused.
    VM: 178T vsize, 4321M framework vsize, 0(0) swapins, 0(0) swapouts.
    Networks: packets: 8912344/9G in, 7124889/6G out.
    Disks: 4128991/98G read, 2841002/61G written.

    PID    USER       %CPU MEM    COMMAND
    1204   tensor9    42.7 1842M  node
    998    _postgres  18.3 512M   postgres
    832    tensor9    9.1  284M   tensor9-appliance
    377    root       2.4  38M    launchd
    421    tensor9    1.8  102M   WindowServer
    88     root       0.9  24M    coreservicesd
    913    _spotlight 0.6  76M    mds_stores
    204    root       0.4  19M    configd
    455    tensor9    0.0  8M     ssh-agent
  EOT
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
