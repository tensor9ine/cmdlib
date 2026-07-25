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
  name        = "disk-list"
  display     = "Disk list"
  description = "Enumerate physical and virtual disks via diskutil list — partition layout, volume names, sizes, types. Read-only."
  icon        = "disk"
  data_access = ["Storage"]
  example_output = <<-EOT
    /dev/disk0 (internal, physical):
       #:                       TYPE NAME                    SIZE       IDENTIFIER
       0:      GUID_partition_scheme                        *1.0 TB     disk0
       1:                        EFI EFI                     524.3 MB   disk0s1
       2:                 Apple_APFS Container disk3         1000.0 GB  disk0s2

    /dev/disk3 (synthesized):
       #:                       TYPE NAME                    SIZE       IDENTIFIER
       0:      APFS Container Scheme -                      +1000.0 GB  disk3
                                     Physical Store disk0s2
       1:                APFS Volume Macintosh HD            10.9 GB    disk3s1
       2:              APFS Snapshot com.apple.os.update-... 10.9 GB    disk3s1s1
       3:                APFS Volume Macintosh HD - Data     412.6 GB   disk3s5
       4:                APFS Volume Preboot                 6.2 GB     disk3s2
       5:                APFS Volume Recovery                1.0 GB     disk3s3
       6:                APFS Volume VM                      2.1 GB     disk3s4
  EOT
}

resource "null_resource" "diskutil" {
  triggers = {
  }
  provisioner "local-exec" {
    command = "diskutil list"
  }
}
