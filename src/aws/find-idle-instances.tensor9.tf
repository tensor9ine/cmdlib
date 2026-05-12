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

# aws-provider 6.x removed `aws_cloudwatch_metric_data`; fall back to
# the AWS CLI via local-exec. `cloudwatch get-metric-statistics` wraps
# the same underlying API the data source did — just returned on
# stdout as the per-instance 24h CPU average.
resource "null_resource" "scan" {
  triggers = {
    region          = var.REGION
    max_cpu_percent = var.MAX_CPU_PERCENT
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      start=$(date -u -v-24H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '-24 hours' +%Y-%m-%dT%H:%M:%SZ)
      end=$(date -u +%Y-%m-%dT%H:%M:%SZ)

      ids=$(aws ec2 describe-instances --region ${var.REGION} \
        --filters 'Name=instance-state-name,Values=running' \
        --query 'Reservations[].Instances[].InstanceId' --output text)

      printf 'instance_id\tavg_cpu_pct\n'
      for id in $ids; do
        avg=$(aws cloudwatch get-metric-statistics --region ${var.REGION} \
          --namespace AWS/EC2 --metric-name CPUUtilization \
          --dimensions Name=InstanceId,Value="$id" \
          --start-time "$start" --end-time "$end" \
          --period 3600 --statistics Average \
          --query 'Datapoints[].Average' --output text \
          | awk 'BEGIN{s=0;n=0} {for(i=1;i<=NF;i++){s+=$i;n++}} END{if(n>0) printf "%.2f", s/n; else print "0"}')
        awk -v id="$id" -v avg="$avg" -v cap="${var.MAX_CPU_PERCENT}" 'BEGIN{ if (avg+0 < cap+0) printf "%s\t%s\n", id, avg }'
      done
    EOT
  }
}
