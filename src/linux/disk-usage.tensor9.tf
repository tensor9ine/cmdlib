terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9" }
    null    = { source = "hashicorp/null" }
  }
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
  data_access = ["Filesystem"]
}

resource "null_resource" "df" {
  triggers = {
    mount_prefix = var.MOUNT_PREFIX
    run_at       = timestamp()
  }
  provisioner "local-exec" {
    command = "df -h | awk 'NR==1 || $6 ~ \"^${var.MOUNT_PREFIX}\"'"
  }
}
