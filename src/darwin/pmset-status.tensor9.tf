terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = "~> 2.41" }
    null       = { source = "hashicorp/null", version = "~> 3.2" }
  }
}

provider "tensor9" {
  mode = "ops"
}

resource "tensor9_command" "this" {
  name        = "pmset-status"
  display     = "Power state"
  description = "Show power-management state via pmset: AC/battery, sleep settings, recent wake/sleep events, assertions keeping the system awake. Read-only."
  icon        = "battery"
  data_access = ["Infrastructure"]
}

resource "null_resource" "pmset" {
  triggers = {
  }
  provisioner "local-exec" {
    command = <<-EOT
      echo '=== pmset -g ==='
      pmset -g
      echo
      echo '=== pmset -g batt ==='
      pmset -g batt
      echo
      echo '=== pmset -g assertions ==='
      pmset -g assertions
      echo
      echo '=== pmset -g log | tail -50 ==='
      pmset -g log | tail -50
    EOT
  }
}
