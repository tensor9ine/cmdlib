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
  example_output = <<-EOT
    === uname -a ===
    Darwin mac-appliance-01 23.5.0 Darwin Kernel Version 23.5.0: Wed May  1 20:12:58 PDT 2024; root:xnu-10063.121.3~5/RELEASE_ARM64_T6020 arm64

    === uptime ===
    14:32  up 12 days,  4:17, 2 users, load averages: 2.14 1.98 1.76

    === sw_vers ===
    ProductName:		macOS
    ProductVersion:		14.5
    BuildVersion:		23F79

    === vm_stat ===
    Mach Virtual Memory Statistics: (page size of 16384 bytes)
    Pages free:                               48213.
    Pages active:                            982347.
    Pages inactive:                          871402.
    Pages speculative:                        20114.
    Pages throttled:                              0.
    Pages wired down:                        173208.
    Pages purgeable:                          31844.
    "Translation faults":                 894213756.
    Pages copy-on-write:                   18342991.
    Pages zero filled:                    612348907.
    Pages reactivated:                      2841003.
    File-backed pages:                       412093.
    Anonymous pages:                        1461770.
    Pages stored in compressor:              784112.
    Pages occupied by compressor:            191204.
    Swapins:                                       0.
    Swapouts:                                      0.

    === system_profiler SPHardwareDataType ===
    Hardware:

        Hardware Overview:

          Model Name: Mac mini
          Model Identifier: Mac14,12
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
