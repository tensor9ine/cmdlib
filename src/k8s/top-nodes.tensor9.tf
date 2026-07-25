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

variable "CLUSTER" {
  type        = string
  description = "EKS cluster name"
  validation {
    condition     = can(regex("^[A-Za-z0-9-]+$", var.CLUSTER))
    error_message = "CLUSTER must be a valid EKS cluster name"
  }
}

variable "SORT_BY" {
  type        = string
  default     = "cpu"
  description = "Sort axis: cpu | memory"
  validation {
    condition     = contains(["cpu", "memory"], var.SORT_BY)
    error_message = "SORT_BY must be one of: cpu, memory"
  }
}

data "aws_region" "current" {}

resource "tensor9_command" "this" {
  name        = "top-nodes"
  display     = "Top nodes"
  description = "`kubectl top nodes` — current CPU + memory usage per node, plus % of allocatable. Requires metrics-server in the target cluster. Pair with `list-nodes` for capacity + conditions context."
  icon        = "activity"
  data_access = ["Infrastructure"]
  example_output = <<-EOT
    NAME                         CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
    ip-10-0-12-34.ec2.internal   3210m        40%    11827Mi         38%
    ip-10-0-45-67.ec2.internal   2870m        35%    10432Mi         33%
    ip-10-0-89-10.ec2.internal   1980m        24%    8214Mi          26%
  EOT
}

resource "null_resource" "top_nodes" {
  triggers = {
    cluster = var.CLUSTER
    sort_by = var.SORT_BY
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      aws eks update-kubeconfig --name ${var.CLUSTER} --region ${data.aws_region.current.region} >/dev/null
      kubectl top nodes --sort-by=${var.SORT_BY}
    EOT
  }
}
