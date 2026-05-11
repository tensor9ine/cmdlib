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
  name        = "disk-list"
  display     = "Disk list"
  description = "Enumerate physical and virtual disks via diskutil list — partition layout, volume names, sizes, types. Read-only."
  icon        = "disk"
  data_access = ["Storage"]
}

resource "null_resource" "diskutil" {
  triggers = {
  }
  provisioner "local-exec" {
    command = "diskutil list"
  }
}
