terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = "~> 2.41" }
    null    = { source = "hashicorp/null", version = "~> 3.2" }
  }
}

provider "tensor9" {
  mode = "ops"
}

variable "UNIT" {
  type        = string
  description = "systemd unit name (e.g. nginx.service)"
  validation {
    condition     = can(regex("^[a-zA-Z0-9_.@-]+$", var.UNIT))
    error_message = "UNIT must contain only letters, digits, and the characters _ . @ -"
  }
}

variable "LINES" {
  type        = number
  default     = 200
  description = "Number of trailing journal lines to read"
  validation {
    condition     = var.LINES >= 1 && var.LINES <= 10000
    error_message = "LINES must be between 1 and 10000"
  }
}

variable "SINCE" {
  type        = string
  default     = "1 hour ago"
  description = "journalctl --since expression (e.g. '1 hour ago', '2026-05-08 09:00')"
  validation {
    condition     = can(regex("^[a-zA-Z0-9 ,:-]+$", var.SINCE))
    error_message = "SINCE may contain only letters, digits, spaces, commas, colons, and hyphens"
  }
}

resource "tensor9_command" "this" {
  name        = "journalctl-tail"
  display     = "Journalctl tail"
  description = "Tail recent journal entries for a systemd unit. Read-only."
  icon        = "logs"
  data_access = ["Logs"]
  example_output = <<-EOT
    Jul 25 13:12:44 ip-10-0-12-34 systemd[1]: Starting nginx.service - nginx - high performance web server...
    Jul 25 13:12:44 ip-10-0-12-34 nginx[2184]: nginx: [warn] conflicting server name "_" on 0.0.0.0:80, ignored
    Jul 25 13:12:44 ip-10-0-12-34 systemd[1]: Started nginx.service - nginx - high performance web server.
    Jul 25 13:31:07 ip-10-0-12-34 systemd[1]: Reloading nginx.service - nginx - high performance web server...
    Jul 25 13:31:07 ip-10-0-12-34 nginx[3120]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
    Jul 25 13:31:07 ip-10-0-12-34 nginx[3120]: nginx: configuration file /etc/nginx/nginx.conf test is successful
    Jul 25 13:31:07 ip-10-0-12-34 systemd[1]: Reloaded nginx.service - nginx - high performance web server.
    Jul 25 14:02:19 ip-10-0-12-34 nginx[2188]: 2026/07/25 14:02:19 [error] 2188#2188: *48213 upstream timed out (110: Connection timed out) while reading response header from upstream, client: 10.0.4.87, server: app.example.com, request: "GET /api/v1/reports/export HTTP/1.1", upstream: "http://127.0.0.1:3000/api/v1/reports/export", host: "app.example.com"
    Jul 25 14:02:19 ip-10-0-12-34 nginx[2188]: 10.0.4.87 - - [25/Jul/2026:14:02:19 +0000] "GET /api/v1/reports/export HTTP/1.1" 504 167 "-" "curl/8.5.0"
    Jul 25 14:18:52 ip-10-0-12-34 nginx[2189]: 10.0.4.61 - - [25/Jul/2026:14:18:52 +0000] "GET /healthz HTTP/1.1" 200 2 "-" "kube-probe/1.29"
  EOT
}

resource "null_resource" "journal" {
  triggers = {
    unit  = var.UNIT
    lines = var.LINES
    since = var.SINCE
  }
  provisioner "local-exec" {
    command = "journalctl -u ${var.UNIT} --no-pager --since \"${var.SINCE}\" -n ${var.LINES}"
  }
}
