terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = "~> 2.41" }
    null    = { source = "hashicorp/null", version = "~> 3.2" }
  }
}

provider "tensor9" {
  mode = "ops"
}

resource "tensor9_command" "this" {
  name        = "host-info"
  display     = "Host info"
  description = "Quick overview of the macOS appliance host: kernel, uptime, memory pressure, OS release, hardware overview. Read-only."
  icon        = "server"
  data_access = ["Infrastructure"]
}

resource "null_resource" "host" {
  triggers = {
  }
  provisioner "local-exec" {
    command = <<-EOT
      echo '=== uname -a ==='
      uname -a
      echo
      echo '=== uptime ==='
      uptime
      echo
      echo '=== sw_vers ==='
      sw_vers
      echo
      echo '=== vm_stat ==='
      vm_stat
      echo
      echo '=== system_profiler SPHardwareDataType ==='
      system_profiler SPHardwareDataType 2>/dev/null
    EOT
  }
}
