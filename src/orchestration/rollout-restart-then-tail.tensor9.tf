terraform {
  required_providers {
    tensor9    = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = "~> 2.41" }
    aws        = { source = "hashicorp/aws", version = "~> 6.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.20" }
    null       = { source = "hashicorp/null", version = "~> 3.2" }
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

variable "DEPLOYMENT" {
  type        = string
  description = "Deployment name to bounce; also used as the app= label selector when tailing"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.DEPLOYMENT))
    error_message = "DEPLOYMENT must be lowercase alphanumeric"
  }
}

variable "NAMESPACE" {
  type        = string
  default     = "production"
  description = "Kubernetes namespace"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.NAMESPACE))
    error_message = "NAMESPACE must be a DNS-safe namespace name"
  }
}

variable "TAIL_LINES" {
  type        = number
  default     = 200
  description = "Lines of post-restart log to fetch from each new pod"
  validation {
    condition     = var.TAIL_LINES >= 1 && var.TAIL_LINES <= 5000
    error_message = "TAIL_LINES must be between 1 and 5000"
  }
}

data "aws_region" "current" {}
data "aws_eks_cluster" "target" { name = var.CLUSTER }
data "aws_eks_cluster_auth" "target" { name = var.CLUSTER }

provider "kubernetes" {
  host                   = data.aws_eks_cluster.target.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.target.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.target.token
}

resource "tensor9_command" "this" {
  name         = "rollout-restart-then-tail"
  display      = "Rollout restart then tail"
  description  = "Bounce a Deployment via the rollout-restartedAt annotation, wait briefly, then tail the new pods' logs as a smoke test. Catches CrashLoopBackOff / ImagePullBackOff that a fire-and-forget restart would silently leave broken."
  icon         = "refresh"
  data_access  = ["Infrastructure", "Logs"]
  side_effects = ["pod-restarts"]
  example_output = <<-EOT
    ==> Step 1/2: Rolling restart of deployment.apps/web in namespace production
        annotated deployment.apps/web: kubectl.kubernetes.io/restartedAt=2026-07-25T14:38:52Z
    ==> Step 2/2: Tailing 200 lines from new pods (app=web), after 10s settle
        Updated context arn:aws:eks:us-east-1:123456789012:cluster/acme-prod in ~/.kube/config
        [pod/web-6f4b7c9d84-qmx7t/web] 2026-07-25T14:39:05.114Z INFO  starting web v2026.7.25 (commit 9f3a1c2)
        [pod/web-6f4b7c9d84-qmx7t/web] 2026-07-25T14:39:05.982Z INFO  listening on :8080
        [pod/web-6f4b7c9d84-wr2ns/web] 2026-07-25T14:39:06.201Z INFO  starting web v2026.7.25 (commit 9f3a1c2)
        [pod/web-6f4b7c9d84-wr2ns/web] 2026-07-25T14:39:06.884Z INFO  listening on :8080
        [pod/web-6f4b7c9d84-zx9pl/web] 2026-07-25T14:39:07.037Z INFO  listening on :8080
    ✓ Completed in 21s — web restarted, 3 new pods logging, no CrashLoopBackOff
  EOT
}

resource "kubernetes_annotations" "rollout_trigger" {
  api_version = "apps/v1"
  kind        = "Deployment"
  metadata {
    name      = var.DEPLOYMENT
    namespace = var.NAMESPACE
  }
  annotations = {
    "kubectl.kubernetes.io/restartedAt" = timestamp()
  }
}

resource "null_resource" "tail_after_restart" {
  depends_on = [kubernetes_annotations.rollout_trigger]

  triggers = {
    cluster      = var.CLUSTER
    deployment   = var.DEPLOYMENT
    namespace    = var.NAMESPACE
    tail_lines   = var.TAIL_LINES
    restarted_at = kubernetes_annotations.rollout_trigger.annotations["kubectl.kubernetes.io/restartedAt"]
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      aws eks update-kubeconfig --name ${var.CLUSTER} --region ${data.aws_region.current.region} >/dev/null
      sleep 10
      kubectl logs -n ${var.NAMESPACE} -l app=${var.DEPLOYMENT} --tail=${var.TAIL_LINES} --all-containers=true --prefix=true
    EOT
  }
}

output "restarted_at" {
  value = kubernetes_annotations.rollout_trigger.annotations["kubectl.kubernetes.io/restartedAt"]
}
