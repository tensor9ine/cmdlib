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

variable "NAMESPACE" {
  type        = string
  default     = "default"
  description = "Kubernetes namespace (set to `all` for cluster-wide top)"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.NAMESPACE))
    error_message = "NAMESPACE must be a DNS-safe namespace name (or `all`)"
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
  name        = "top-pods"
  display     = "Top pods"
  description = "`kubectl top pods` — current CPU + memory usage per pod. Requires metrics-server to be installed and running in the target cluster; fails clearly if it isn't."
  icon        = "activity"
  data_access = ["Infrastructure"]
  example_output = <<-EOT
    NAME                     CPU(cores)   MEMORY(bytes)
    api-7f9c8d4b6-9jhcd      420m         318Mi
    api-7f9c8d4b6-xk2m9      385m         305Mi
    api-7f9c8d4b6-p8wqz      360m         298Mi
    web-5d8c9f7b4-2xq9p      210m         246Mi
    api-7f9c8d4b6-r3ntv      190m         402Mi
    web-5d8c9f7b4-7bkzr      175m         238Mi
    web-5d8c9f7b4-t4m8n      160m         233Mi
    worker-6b7d8c9f5-hs2kq   95m          180Mi
    worker-6b7d8c9f5-mn4pl   88m          176Mi
  EOT
}

resource "null_resource" "top_pods" {
  triggers = {
    cluster   = var.CLUSTER
    namespace = var.NAMESPACE
    sort_by   = var.SORT_BY
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      aws eks update-kubeconfig --name ${var.CLUSTER} --region ${data.aws_region.current.region} >/dev/null
      if [ "${var.NAMESPACE}" = "all" ]; then
        kubectl top pods --all-namespaces --sort-by=${var.SORT_BY}
      else
        kubectl top pods --namespace=${var.NAMESPACE} --sort-by=${var.SORT_BY}
      fi
    EOT
  }
}
