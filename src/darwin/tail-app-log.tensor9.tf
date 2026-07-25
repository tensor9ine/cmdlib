terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = "~> 2.41" }
    null    = { source = "hashicorp/null", version = "~> 3.2" }
  }
}

provider "tensor9" {
  mode = "ops"
}

variable "PATH" {
  type        = string
  description = "Absolute path to the log file to tail. Must live under /Library/Logs, /var/log, /tmp, or the user's ~/Library/Logs."
  validation {
    condition = (
      startswith(var.PATH, "/Library/Logs/") ||
      startswith(var.PATH, "/var/log/") ||
      startswith(var.PATH, "/tmp/") ||
      can(regex("^/Users/[^/]+/Library/Logs/", var.PATH))
    )
    error_message = "PATH must live under /Library/Logs, /var/log, /tmp, or ~/Library/Logs"
  }
}

variable "LINES" {
  type        = number
  default     = 200
  description = "Number of trailing lines to show (1-2000)"
  validation {
    condition     = var.LINES >= 1 && var.LINES <= 2000
    error_message = "LINES must be between 1 and 2000"
  }
}

resource "tensor9_command" "this" {
  name        = "tail-app-log"
  display     = "Tail app log"
  description = "Snapshot the last LINES of an application log file under the allowed log roots. Read-only."
  icon        = "file-text"
  data_access = ["Logs"]
  example_output = <<-EOT
    2026-07-25T14:27:41.882-0700 INFO  [actuator] heartbeat ok seq=48211 rtt=11ms
    2026-07-25T14:27:52.014-0700 INFO  [sip] tunnel prod-1.tensor9.com:8443 healthy (16/16 slots)
    2026-07-25T14:28:03.220-0700 WARN  [runtime] node worker pid=1204 rss=1842MB approaching soft limit 2048MB
    2026-07-25T14:28:11.457-0700 INFO  [runtime] GET /healthz 200 3ms
    2026-07-25T14:28:19.771-0700 INFO  [pg] checkpoint complete: wrote 812 buffers (2.4%)
    2026-07-25T14:28:24.004-0700 ERROR [sip] control-plane dial failed: i/o timeout (attempt 1/3)
    2026-07-25T14:28:24.559-0700 INFO  [sip] control-plane reconnected after 555ms
    2026-07-25T14:28:33.472-0700 INFO  [actuator] executed command disk-usage in 42ms (exit=0)
    2026-07-25T14:28:41.905-0700 INFO  [actuator] heartbeat ok seq=48213 rtt=12ms
  EOT
}

resource "null_resource" "tail" {
  triggers = {
    path  = var.PATH
    lines = var.LINES
  }
  provisioner "local-exec" {
    command = "tail -n ${var.LINES} '${var.PATH}'"
  }
}
