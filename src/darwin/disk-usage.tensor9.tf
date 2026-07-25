terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = "~> 2.41" }
    null    = { source = "hashicorp/null", version = "~> 3.2" }
  }
}

provider "tensor9" {
  mode = "ops"
}

variable "MOUNT_PREFIX" {
  type        = string
  default     = "/"
  description = "Filesystem path prefix; only mounts under this prefix are reported"
  validation {
    condition     = startswith(var.MOUNT_PREFIX, "/")
    error_message = "MOUNT_PREFIX must be an absolute path beginning with /"
  }
}

resource "tensor9_command" "this" {
  name        = "disk-usage"
  display     = "Disk usage"
  description = "Show human-readable disk usage (df -h) for mounts under MOUNT_PREFIX. Read-only."
  icon        = "disk"
  data_access = ["Storage"]
  example_output = <<-EOT
    Filesystem        Size   Used  Avail Capacity iused    ifree %iused  Mounted on
    /dev/disk3s1s1   926Gi   11Gi  287Gi     4%    404k     3.0G    0%   /
    devfs            206Ki  206Ki    0Bi   100%     712        0  100%   /dev
    /dev/disk3s6     926Gi  2.1Gi  287Gi     1%       2     3.0G    0%   /System/Volumes/VM
    /dev/disk3s2     926Gi  6.2Gi  287Gi     3%    1234     3.0G    0%   /System/Volumes/Preboot
    /dev/disk3s4     926Gi  413Gi  287Gi    59%    1.4M     3.0G    0%   /System/Volumes/Data
    map auto_home      0Bi    0Bi    0Bi   100%       0        0  100%   /System/Volumes/Data/home
  EOT
}

resource "null_resource" "df" {
  triggers = {
    mount_prefix = var.MOUNT_PREFIX
  }
  provisioner "local-exec" {
    command = "df -h | awk 'NR==1 || $9 ~ \"^${var.MOUNT_PREFIX}\"'"
  }
}
