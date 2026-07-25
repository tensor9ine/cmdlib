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
  default     = 100
  description = "Number of trailing kernel ring buffer lines to read"
  validation {
    condition     = var.LINES >= 1 && var.LINES <= 1000
    error_message = "LINES must be between 1 and 1000"
  }
}

resource "tensor9_command" "this" {
  name        = "dmesg-tail"
  display     = "Dmesg tail"
  description = "Read the last LINES from the kernel ring buffer (dmesg). Read-only."
  icon        = "logs"
  data_access = ["Logs"]
  example_output = <<-EOT
    [Sat Jul 25 05:58:41 2026] docker0: port 3(veth9a1f2c4) entered blocking state
    [Sat Jul 25 05:58:41 2026] docker0: port 3(veth9a1f2c4) entered disabled state
    [Sat Jul 25 05:58:41 2026] veth9a1f2c4: entered allmulticast mode
    [Sat Jul 25 05:58:41 2026] veth9a1f2c4: entered promiscuous mode
    [Sat Jul 25 05:58:42 2026] eth0: renamed from vethb77e0d1
    [Sat Jul 25 05:58:42 2026] docker0: port 3(veth9a1f2c4) entered blocking state
    [Sat Jul 25 05:58:42 2026] docker0: port 3(veth9a1f2c4) entered forwarding state
    [Sat Jul 25 09:14:03 2026] TCP: request_sock_TCP: Possible SYN flooding on port 443. Sending cookies.  Check SNMP counters.
    [Sat Jul 25 11:22:57 2026] nvme nvme2: I/O 384 QID 3 timeout, completion polled
    [Sat Jul 25 12:03:19 2026] audit: type=1400 audit(1785326599.412:88): apparmor="DENIED" operation="open" profile="docker-default" name="/proc/sys/kernel/random/boot_id" pid=31842 comm="node"
    [Sat Jul 25 13:47:11 2026] docker0: port 3(veth9a1f2c4) entered disabled state
    [Sat Jul 25 13:47:11 2026] veth9a1f2c4 (unregistering): left allmulticast mode
  EOT
}

resource "null_resource" "dmesg" {
  triggers = {
    lines = var.LINES
  }
  provisioner "local-exec" {
    command = "dmesg --ctime | tail -n ${var.LINES}"
  }
}
