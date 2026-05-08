terraform {
  required_providers {
    tensor9 = { source = "tensor9/tensor9" }
    null    = { source = "hashicorp/null" }
  }
}

resource "tensor9_command" "this" {
  name        = "host-info"
  display     = "Host info"
  description = "Quick overview of the appliance host: kernel, uptime, memory, and distro release. Read-only."
  icon        = "server"
  data_access = ["Infrastructure"]
}

resource "null_resource" "host" {
  triggers = {
    run_at = timestamp()
  }
  provisioner "local-exec" {
    command = <<-EOT
      echo '=== uname -a ==='
      uname -a
      echo
      echo '=== uptime ==='
      uptime
      echo
      echo '=== free -h ==='
      free -h
      echo
      echo '=== lsb_release -a ==='
      (lsb_release -a 2>/dev/null) || cat /etc/os-release
    EOT
  }
}
