terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = "~> 2.41" }
    null    = { source = "hashicorp/null", version = "~> 3.2" }
  }
}

provider "tensor9" {
  mode = "ops"
}

variable "DATA_TYPE" {
  type        = string
  default     = "SPHardwareDataType"
  description = "system_profiler data type (e.g. SPHardwareDataType, SPSoftwareDataType, SPNetworkDataType, SPStorageDataType)"
  validation {
    # Hard-fail anything that isn't a well-formed `SP<Word>DataType`
    # token — everything else is rejected before shelling out.
    condition     = can(regex("^SP[A-Za-z0-9]+DataType$", var.DATA_TYPE))
    error_message = "DATA_TYPE must match the SP<...>DataType form (see system_profiler -listDataTypes)"
  }
}

resource "tensor9_command" "this" {
  name        = "system-profile"
  display     = "System profile"
  description = "Dump a system_profiler data type (hardware, software, network, storage, etc.) for the macOS host. Read-only."
  icon        = "info"
  data_access = ["Infrastructure"]
  example_output = <<-EOT
    Hardware:

        Hardware Overview:

          Model Name: Mac mini
          Model Identifier: Mac14,12
          Model Number: Z170000BXA/A
          Chip: Apple M2 Pro
          Total Number of Cores: 12 (8 performance and 4 efficiency)
          Memory: 32 GB
          System Firmware Version: 10151.121.1
          OS Loader Version: 10151.121.1
          Serial Number (system): H2WXYZ1234AB
          Hardware UUID: 5B2E9C4A-7F13-5D8E-A1B6-3C9F0E2D4A71
          Provisioning UDID: 00006020-000A1D2E3C4B5F26
          Activation Lock Status: Disabled
  EOT
}

resource "null_resource" "system_profiler" {
  triggers = {
    data_type = var.DATA_TYPE
  }
  provisioner "local-exec" {
    command = "system_profiler ${var.DATA_TYPE}"
  }
}
