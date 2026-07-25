terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = "~> 2.41" }
    null    = { source = "hashicorp/null", version = "~> 3.2" }
  }
}

provider "tensor9" {
  mode = "ops"
}

variable "LINES" {
  type        = number
  default     = 200
  description = "Number of trailing lines to read"
  validation {
    condition     = var.LINES >= 1 && var.LINES <= 10000
    error_message = "LINES must be between 1 and 10000"
  }
}

variable "LOG_PATH" {
  type        = string
  default     = "/var/log/app/current.log"
  description = "Absolute path to a log file under /var/log/"
  validation {
    condition     = startswith(var.LOG_PATH, "/var/log/")
    error_message = "LOG_PATH must be inside /var/log/"
  }
}

resource "tensor9_command" "this" {
  name        = "tail-app-log"
  display     = "Tail app log"
  description = "Read the last LINES of an on-host log file under /var/log/. Read-only diagnostics — no mutation."
  icon        = "logs"
  data_access = ["Logs"]
  example_output = <<-EOT
    {"time":"2026-07-25T14:30:58.114Z","level":"info","msg":"request completed","method":"GET","path":"/api/v1/reports","status":200,"dur_ms":42,"req_id":"a1f2c4d9"}
    {"time":"2026-07-25T14:31:02.881Z","level":"info","msg":"request completed","method":"POST","path":"/api/v1/orders","status":201,"dur_ms":118,"req_id":"b7e0d1a3"}
    {"time":"2026-07-25T14:31:05.402Z","level":"warn","msg":"slow query","query":"orders.findByCustomer","dur_ms":812,"req_id":"b7e0d1a3"}
    {"time":"2026-07-25T14:31:07.219Z","level":"info","msg":"request completed","method":"GET","path":"/healthz","status":200,"dur_ms":1,"req_id":"c0114e77"}
    {"time":"2026-07-25T14:31:12.660Z","level":"info","msg":"pg pool acquired","pool":"primary","in_use":6,"idle":4,"waiting":0}
    {"time":"2026-07-25T14:31:18.043Z","level":"warn","msg":"rate limit near threshold","tenant":"acme","window":"1m","count":964,"limit":1000}
    {"time":"2026-07-25T14:31:49.502Z","level":"error","msg":"upstream request failed","upstream":"payments-svc","status":504,"dur_ms":30012,"req_id":"d3a91b02","err":"ETIMEDOUT"}
    {"time":"2026-07-25T14:31:49.511Z","level":"info","msg":"retry scheduled","upstream":"payments-svc","attempt":1,"backoff_ms":500,"req_id":"d3a91b02"}
    {"time":"2026-07-25T14:31:50.130Z","level":"info","msg":"request completed","method":"POST","path":"/api/v1/checkout","status":200,"dur_ms":734,"req_id":"d3a91b02"}
    {"time":"2026-07-25T14:32:04.777Z","level":"info","msg":"request completed","method":"GET","path":"/api/v1/reports","status":200,"dur_ms":38,"req_id":"e5620ff1"}
  EOT
}

resource "null_resource" "tail" {
  triggers = {
    log_path = var.LOG_PATH
    lines    = var.LINES
  }
  provisioner "local-exec" {
    command = "tail -n ${var.LINES} ${var.LOG_PATH}"
  }
}
