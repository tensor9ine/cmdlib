# k8s — Kubernetes / EKS ops command templates

This directory holds `*.tensor9.tf` templates for SRE-grade operational
commands that target a Kubernetes cluster running on EKS. Each file
declares a single `tensor9_command "this"` resource — the Tensor9 control
plane discovers them, renders them as buttons in the appliance UI, and
runs `terraform apply` with operator-supplied variables when invoked.

## Auth pattern

Tensor9's appliance ships with AWS credentials scoped to its own VPC
account. We lean on that and let AWS broker the Kubernetes auth:

```hcl
data "aws_eks_cluster"      "target" { name = var.CLUSTER }
data "aws_eks_cluster_auth" "target" { name = var.CLUSTER }

provider "kubernetes" {
  host                   = data.aws_eks_cluster.target.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.target.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.target.token
}
```

`aws_eks_cluster_auth` performs the EKS IAM-to-bearer-token handshake
under the appliance's IAM role — no kubeconfig file, no static
serviceaccount tokens to rotate. Templates that shell out to `kubectl`
instead run `aws eks update-kubeconfig` in their `local-exec` block,
which uses the same handshake.

## CLUSTER variable convention

Every template in this directory takes a `CLUSTER` variable naming the
EKS cluster to target. This is enforced rather than inferred so a single
appliance can manage multiple clusters (prod + staging, or per-region
fleets) and the operator picks per-invocation.

## Templates

| Template | Type | Description |
|---|---|---|
| `list-stuck-pods.tensor9.tf`          | read-only | Pods that haven't been Ready past `MIN_AGE_SECONDS` |
| `tail-pod-logs.tensor9.tf`            | read-only | Trailing 2 MiB of a pod's logs (up to 20k lines) |
| `get-events.tensor9.tf`               | read-only | Most recent Warning events in a namespace |
| `describe-deployment.tensor9.tf`      | read-only | Full Deployment status, conditions, replica counts |
| `restart-deployment.tensor9.tf`       | mutating  | Rolling restart via `kubectl.kubernetes.io/restartedAt` |
| `restart-pods-by-label.tensor9.tf`    | mutating  | Delete pods matching a label selector |
| `scale-deployment.tensor9.tf`         | mutating  | Set a Deployment's replica count |
| `drain-node.tensor9.tf`               | mutating  | Cordon a node and evict its pods (skipping DaemonSets) |
| `delete-failed-evicted-pods.tensor9.tf` | mutating | GC pods in Failed/Evicted/Succeeded phase |

Read-only templates declare `data_access` only. Mutating templates also
declare `side_effects` so the control plane can gate them behind the
appropriate approval policy.

## See also

- `../orchestration/` — cross-provider templates that combine
  Kubernetes ops with surrounding AWS work (e.g. drain a node *and*
  terminate its EC2 instance; scale a Deployment *and* scale the
  underlying ASG).
- `../aws/` — AWS-only ops templates (no Kubernetes provider).
