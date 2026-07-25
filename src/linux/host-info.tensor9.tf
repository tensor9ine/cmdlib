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
  description = "Quick overview of the appliance host: kernel, uptime, memory, and distro release. Read-only."
  icon        = "server"
  data_access = ["Infrastructure"]
  example_output = <<-EOT
    === uname -a ===
    Linux ip-10-0-12-34 6.1.94-99.176.amzn2023.x86_64 #1 SMP PREEMPT_DYNAMIC Fri Jul  3 22:15:31 UTC 2026 x86_64 x86_64 x86_64 GNU/Linux

    === uptime ===
     14:32:07 up 27 days,  3:41,  0 users,  load average: 0.42, 0.51, 0.48

    === free -h ===
                   total        used        free      shared  buff/cache   available
    Mem:            31Gi       9.8Gi       2.1Gi       412Mi        19Gi        20Gi
    Swap:             0B          0B          0B

    === lsb_release -a ===
    NAME="Amazon Linux"
    VERSION="2023"
    ID="amzn"
    ID_LIKE="fedora"
    VERSION_ID="2023"
    PLATFORM_ID="platform:al2023"
    PRETTY_NAME="Amazon Linux 2023.5.20260714"
    ANSI_COLOR="0;33"
    HOME_URL="https://aws.amazon.com/linux/amazon-linux-2023/"
  EOT
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
      echo '=== free -h ==='
      free -h
      echo
      echo '=== lsb_release -a ==='
      (lsb_release -a 2>/dev/null) || cat /etc/os-release
    EOT
  }
}
