terraform {
  required_providers {
    tensor9 = { source = "tensor9/tensor9" }
    aws     = { source = "hashicorp/aws" }
  }
}

variable "REGION" {
  type        = string
  default     = "us-west-2"
  description = "AWS region to scan"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.REGION))
    error_message = "REGION must be a valid AWS region identifier"
  }
}

variable "MAX_CPU_PERCENT" {
  type        = number
  default     = 5
  description = "Average CPU% upper bound to consider an instance idle"
  validation {
    condition     = var.MAX_CPU_PERCENT > 0 && var.MAX_CPU_PERCENT <= 100
    error_message = "MAX_CPU_PERCENT must be between 1 and 100"
  }
}

provider "aws" {
  region = var.REGION
}

resource "tensor9_command" "this" {
  name        = "find-idle-instances"
  display     = "Find idle EC2 instances"
  description = "List running EC2 instances whose average CPU utilization is below MAX_CPU_PERCENT% over the last 24h. Read-only."
  icon        = "search"
  data_access = ["Infrastructure", "Metrics"]
}

data "aws_instances" "running" {
  instance_state_names = ["running"]
}

data "aws_cloudwatch_metric_data" "cpu" {
  for_each = toset(data.aws_instances.running.ids)

  metric_data_query {
    id          = "cpu"
    return_data = true
    metric_stat {
      period = 3600
      stat   = "Average"
      metric {
        metric_name = "CPUUtilization"
        namespace   = "AWS/EC2"
        dimensions = {
          InstanceId = each.value
        }
      }
    }
  }

  start_time = timeadd(timestamp(), "-24h")
  end_time   = timestamp()
}

output "idle_instances" {
  value = [
    for id in data.aws_instances.running.ids : {
      instance_id = id
      avg_cpu     = try(
        length(data.aws_cloudwatch_metric_data.cpu[id].metric_data_results[0].values) > 0
          ? (
              sum(data.aws_cloudwatch_metric_data.cpu[id].metric_data_results[0].values)
              / length(data.aws_cloudwatch_metric_data.cpu[id].metric_data_results[0].values)
            )
          : 0,
        0
      )
    }
    if try(
      length(data.aws_cloudwatch_metric_data.cpu[id].metric_data_results[0].values) > 0
        && (
          sum(data.aws_cloudwatch_metric_data.cpu[id].metric_data_results[0].values)
          / length(data.aws_cloudwatch_metric_data.cpu[id].metric_data_results[0].values)
        ) < var.MAX_CPU_PERCENT,
      false
    )
  ]
}
