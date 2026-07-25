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
  name        = "pmset-status"
  display     = "Power state"
  description = "Show power-management state via pmset: AC/battery, sleep settings, recent wake/sleep events, assertions keeping the system awake. Read-only."
  icon        = "battery"
  data_access = ["Infrastructure"]
  example_output = <<-EOT
    === pmset -g ===
    System-wide power settings:
    Currently in use:
     standby              1
     Sleep On Power Button 1
     hibernatefile        /var/vm/sleepimage
     powernap             0
     networkoversleep     0
     disksleep            10
     sleep                0 (sleep prevented by tensor9-appliance)
     autopoweroffdelay    28800
     hibernatemode        0
     autopoweroff         1
     ttyskeepawake        1
     displaysleep         10
     tcpkeepalive         1
     standbydelayhigh     86400
     standbydelaylow      86400
     womp                 1

    === pmset -g batt ===
    Now drawing from 'AC Power'

    === pmset -g assertions ===
    2026-07-25 14:32:05 -0700
    Assertion status system-wide:
       BackgroundTask                 0
       ApplePushServiceTask           0
       UserIsActive                   0
       PreventUserIdleDisplaySleep    0
       PreventUserIdleSystemSleep     1
       PreventSystemSleep             1
       ExternalMedia                  0
       PreventDisplaySleep            0
       NetworkClientActive            1

    Listed by owning process:
       pid 832(tensor9-appliance): [0x0000000d00120e47] 03:47:12 PreventUserIdleSystemSleep named: "tensor9 actuator session active"
       pid 998(postgres): [0x0000000a000f0b21] 12:04:55 NetworkClientActive named: "libpq listener"

    === pmset -g log | tail -50 ===
    2026-07-24 02:14:07 -0700 Sleep                	Entering Sleep state due to 'Software Sleep pid=1': Using AC (Charge:0%)
    2026-07-24 02:41:33 -0700 Wake                 	Wake from Normal Sleep [CDNVA] due to RTC/Maintenance
    2026-07-24 02:41:39 -0700 WakeDetails          	Wake reason: RTC (Alarm)
    2026-07-24 07:59:52 -0700 DarkWake             	DarkWake to FullWake from Normal Sleep [CDNVA] due to EC.PowerButton
    2026-07-25 09:14:22 -0700 Assertions           	PID 832(tensor9-appliance) Created PreventUserIdleSystemSleep "tensor9 actuator session active"
    2026-07-25 14:32:05 -0700 Assertions           	Summary- [System: PrevIdle DeclUser kDisplayOn]
  EOT
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
