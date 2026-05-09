terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = ">= 2.41.0" }
    null    = { source = "hashicorp/null" }
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
}

resource "null_resource" "system_profiler" {
  triggers = {
    data_type = var.DATA_TYPE
    run_at    = timestamp()
  }
  provisioner "local-exec" {
    command = "system_profiler ${var.DATA_TYPE}"
  }
}
