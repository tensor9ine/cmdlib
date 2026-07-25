terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = "~> 2.41" }
    aws     = { source = "hashicorp/aws", version = "~> 6.0" }
    null    = { source = "hashicorp/null", version = "~> 3.2" }
  }
}

provider "tensor9" {
  mode = "ops"
}

provider "aws" {}

# Two-step CPU profile via Node's inspector protocol:
#   1. Signal the Node process to enable the inspector on INSPECTOR_PORT (SIGUSR1).
#   2. Talk to the inspector HTTP endpoint to start a CPU profile, sleep DURATION,
#      then stop the profile and emit it to stdout.
# Assumes the app was started with `node` (so SIGUSR1 wakes the inspector) and
# that INSPECTOR_PORT is not bound by something else inside the container.

variable "CLUSTER" {
  type        = string
  description = "EKS cluster name"
  validation {
    condition     = can(regex("^[A-Za-z0-9-]+$", var.CLUSTER))
    error_message = "CLUSTER must be a valid EKS cluster name"
  }
}

variable "POD" {
  type        = string
  description = "Pod hosting the Node.js process"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.POD))
    error_message = "POD must be a DNS-safe pod name"
  }
}

variable "NAMESPACE" {
  type        = string
  default     = "default"
  description = "Kubernetes namespace"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.NAMESPACE))
    error_message = "NAMESPACE must be a DNS-safe namespace name"
  }
}

variable "CONTAINER" {
  type        = string
  default     = ""
  description = "Container name within the pod (empty = first container)"
  validation {
    condition     = var.CONTAINER == "" || can(regex("^[a-z0-9-]+$", var.CONTAINER))
    error_message = "CONTAINER must be empty or a DNS-safe container name"
  }
}

variable "DURATION_SECONDS" {
  type        = number
  default     = 10
  description = "Profile sample duration in seconds"
  validation {
    condition     = var.DURATION_SECONDS >= 1 && var.DURATION_SECONDS <= 120
    error_message = "DURATION_SECONDS must be between 1 and 120"
  }
}

variable "INSPECTOR_PORT" {
  type        = number
  default     = 9229
  description = "TCP port the Node inspector should listen on inside the container"
  validation {
    condition     = var.INSPECTOR_PORT >= 1024 && var.INSPECTOR_PORT <= 65535
    error_message = "INSPECTOR_PORT must be between 1024 and 65535"
  }
}

data "aws_region" "current" {}

resource "tensor9_command" "this" {
  name        = "cpu-profile"
  display     = "Capture CPU profile"
  description = "Collect a v8 CPU sampling profile from a running Node.js process via the inspector protocol. Wakes the inspector with SIGUSR1, samples for DURATION_SECONDS, then prints the .cpuprofile JSON. Read-only with respect to app state, but briefly opens the inspector port."
  icon        = "cpu"
  data_access = ["Metrics"]
  example_output = <<-EOT
    inspector_ws=ws://localhost:9229/8f3a1c2e-6b0d-4a4f-9c31-2d7e5a9b0f14
    {"nodes":[{"id":1,"callFrame":{"functionName":"(root)","scriptId":"0","url":"","lineNumber":-1,"columnNumber":-1},"hitCount":0,"children":[2,3,4]},{"id":2,"callFrame":{"functionName":"(program)","scriptId":"0","url":"","lineNumber":-1,"columnNumber":-1},"hitCount":12},{"id":3,"callFrame":{"functionName":"(idle)","scriptId":"0","url":"","lineNumber":-1,"columnNumber":-1},"hitCount":3201},{"id":4,"callFrame":{"functionName":"query","scriptId":"142","url":"file:///app/node_modules/pg/lib/client.js","lineNumber":508,"columnNumber":22},"hitCount":4820,"children":[5]},{"id":5,"callFrame":{"functionName":"parse","scriptId":"151","url":"file:///app/node_modules/pg-protocol/dist/parser.js","lineNumber":97,"columnNumber":14},"hitCount":1948}],"startTime":264518993217,"endTime":264528994061,"samples":[3,3,4,4,5,4,3,2],"timeDeltas":[112,98,101,99,103,97,100,102]}
  EOT
}

resource "null_resource" "profile" {
  triggers = {
    cluster   = var.CLUSTER
    pod       = var.POD
    namespace = var.NAMESPACE
    container = var.CONTAINER
    duration  = var.DURATION_SECONDS
    port      = var.INSPECTOR_PORT
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      aws eks update-kubeconfig --name ${var.CLUSTER} --region ${data.aws_region.current.region} >/dev/null
      KEXEC="kubectl exec ${var.POD} -n ${var.NAMESPACE} ${var.CONTAINER == "" ? "" : "-c ${var.CONTAINER}"} --"
      # Step 1: wake inspector (idempotent — SIGUSR1 enables if disabled).
      $KEXEC kill -USR1 1 || true
      sleep 1
      # Step 2: discover the websocket debugger URL.
      WSURL=$($KEXEC sh -c "wget -qO- http://localhost:${var.INSPECTOR_PORT}/json | grep -o 'ws://[^\"]*' | head -n1")
      echo "inspector_ws=$WSURL"
      # Step 3: drive Profiler.start / sleep / Profiler.stop using a small Node client in the pod.
      $KEXEC node -e "
        const WS=require('ws');const ws=new WS('$WSURL');let id=0;
        const send=(m)=>ws.send(JSON.stringify({id:++id,...m}));
        ws.on('open',()=>{send({method:'Profiler.enable'});send({method:'Profiler.start'});
          setTimeout(()=>send({method:'Profiler.stop'}),${var.DURATION_SECONDS * 1000});});
        ws.on('message',(d)=>{const m=JSON.parse(d);if(m.result&&m.result.profile){console.log(JSON.stringify(m.result.profile));ws.close();process.exit(0);}});
      "
    EOT
  }
}
