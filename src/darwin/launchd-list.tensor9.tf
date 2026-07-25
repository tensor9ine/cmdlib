terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = "~> 2.41" }
    null    = { source = "hashicorp/null", version = "~> 3.2" }
  }
}

provider "tensor9" {
  mode = "ops"
}

variable "FILTER" {
  type        = string
  default     = ""
  description = "Substring filter applied to launchd labels (e.g. 'tensor9' or 'com.apple'). Empty = list all."
}

resource "tensor9_command" "this" {
  name        = "launchd-list"
  display     = "Launchd services"
  description = "List launchd jobs (launchctl list), optionally filtered by label substring. Read-only."
  icon        = "list"
  data_access = ["Infrastructure"]
  example_output = <<-EOT
    PID	Status	Label
    1	0	com.apple.SafariHistoryServiceAgent
    -	0	com.apple.mdworker.shared.05000000-0700-0000-0000-000000000000
    832	0	com.tensor9.appliance
    -	0	com.apple.progressd
    1204	0	com.tensor9.appliance.node-runtime
    998	0	org.postgresql.postgres
    -	0	com.apple.cvmsCompAgent
    421	0	com.apple.usernoted
    -	-	com.apple.mdworker.mail
    377	0	com.openssh.ssh-agent
    88	0	com.apple.coreservices.launchservicesd
  EOT
}

resource "null_resource" "launchd" {
  triggers = {
    filter = var.FILTER
  }
  provisioner "local-exec" {
    # Output columns: PID, Status, Label. PID is `-` when not running;
    # Status is the last exit code (or `-` for "never run").
    command = var.FILTER == "" ? "launchctl list" : "launchctl list | awk 'NR==1 || /${var.FILTER}/'"
  }
}
