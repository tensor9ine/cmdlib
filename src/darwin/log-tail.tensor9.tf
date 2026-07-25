terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = "~> 2.41" }
    null    = { source = "hashicorp/null", version = "~> 3.2" }
  }
}

provider "tensor9" {
  mode = "ops"
}

variable "WINDOW" {
  type        = string
  default     = "5m"
  description = "Lookback window for log show (e.g. 1m, 5m, 1h, 1d)"
  validation {
    condition     = can(regex("^[0-9]+(s|m|h|d)$", var.WINDOW))
    error_message = "WINDOW must be a number followed by s, m, h, or d"
  }
}

variable "PREDICATE" {
  type        = string
  default     = ""
  description = "Optional log show predicate (e.g. 'process == \"kernel\"' or 'subsystem == \"com.apple.network\"'). Empty = all events."
}

resource "tensor9_command" "this" {
  name        = "log-tail"
  display     = "Recent system logs"
  description = "Tail unified-logging events from the last WINDOW (replaces dmesg/journalctl on macOS). Read-only."
  icon        = "file-text"
  data_access = ["Logs"]
  example_output = <<-EOT
    2026-07-25 14:28:03.114217-0700 Df kernel[0:1a2b] (Sandbox) tensor9-appliance(832) allow(1) network-outbound 34.117.59.81:8443
    2026-07-25 14:28:05.902411-0700 In tensor9-appliance[832:12841] [com.tensor9.appliance:sip] tunnel heartbeat ok seq=48211 rtt=11ms
    2026-07-25 14:28:11.338902-0700 Df node[1204:13002] [com.tensor9.appliance:runtime] GET /healthz 200 3ms
    2026-07-25 14:28:19.771120-0700 Df postgres[998:9f01] [org.postgresql:checkpoint] checkpoint complete: wrote 812 buffers
    2026-07-25 14:28:24.004518-0700 Er tensor9-appliance[832:12841] [com.tensor9.appliance:sip] control-plane dial failed: i/o timeout (attempt 1/3)
    2026-07-25 14:28:24.559803-0700 In tensor9-appliance[832:12841] [com.tensor9.appliance:sip] control-plane reconnected prod-1.tensor9.com:8443
    2026-07-25 14:28:41.220774-0700 Df kernel[0:1a2b] (AppleMobileFileIntegrity) unrestrict process 1204
  EOT
}

resource "null_resource" "log_show" {
  triggers = {
    window    = var.WINDOW
    predicate = var.PREDICATE
  }
  provisioner "local-exec" {
    # `log show --style compact` strips the verbose default columns;
    # the predicate slot lets the operator narrow when needed.
    command = var.PREDICATE == "" ? "log show --style compact --last ${var.WINDOW}" : "log show --style compact --last ${var.WINDOW} --predicate '${var.PREDICATE}'"
  }
}
