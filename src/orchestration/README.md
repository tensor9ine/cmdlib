# orchestration — multi-step, cross-provider ops command templates

This directory holds `*.tensor9.tf` templates that compose multiple
providers (AWS + Kubernetes + `null_resource`) into a single ordered
workflow. Each file is one operator-facing command, but the work it
performs is several steps that must run in a specific order.

The single-provider building blocks live next door:

- `../aws/` — AWS-only templates (snapshots, IAM rotations, instance ops).
- `../k8s/` — Kubernetes-only templates (rollout restarts, drains, scales).

When a runbook needs *both* — "snapshot the DB, then bounce the API" or
"drain the node, then terminate the EC2 backing it" — that's an
orchestration template, and it lives here.

## Why a separate category

The buyer-side approval model is per-template. When an operator clicks
*Run* on a single-provider template, the buyer's policy engine inspects
the `data_access` and `side_effects` declared on the
`tensor9_command "this"` resource and decides whether the command is
allowed under the active policy. A multi-step workflow built by chaining
two single-provider commands would force the buyer to approve each step
*independently*, with no guarantee the second step ever runs (or runs in
a sane order). Orchestration templates collapse the workflow into one
approval: the buyer sees the full graph at approval time and the whole
thing applies as one unit.

## The `depends_on` pattern

Terraform's default execution model parallelizes resources that don't
reference each other. For ops orchestration that's a footgun — without
explicit ordering you can get pod restarts kicking off before the
snapshot has actually completed, or an EC2 termination racing the node
drain. Every resource in this directory that has a logical predecessor
declares it via `depends_on`, even when an attribute reference would
*also* induce the dependency. This is load-bearing for two reasons:

1. **Runtime correctness** — the second step must not start until the
   first has fully applied (snapshot reaches `completed`, node finishes
   draining, etc.).
2. **Approval-time legibility** — the buyer's pre-apply review reads the
   `depends_on` graph to render a "this will run, then this, then this"
   timeline. Implicit dependencies through interpolation work for
   Terraform but are invisible in that review.

## Auth pattern

Same as `../k8s/`. AWS credentials are ambient — supplied to the
appliance's actuator at boot, picked up by `provider "aws" {}` with no
explicit config. Kubernetes auth is brokered through AWS:

```hcl
data "aws_eks_cluster"      "target" { name = var.CLUSTER }
data "aws_eks_cluster_auth" "target" { name = var.CLUSTER }

provider "kubernetes" {
  host                   = data.aws_eks_cluster.target.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.target.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.target.token
}
```

Templates that shell out to `kubectl` from a `null_resource` run
`aws eks update-kubeconfig` first, which uses the same handshake.

## Templates

| Template | Sequence |
|---|---|
| `snapshot-then-restart.tensor9.tf`        | EBS snapshot of DB volume -> rolling restart of API Deployment |
| `drain-then-terminate-node.tensor9.tf`    | `kubectl drain` node -> `aws ec2 terminate-instances` on the EC2 backing it |
| `snapshot-then-resize-volume.tensor9.tf`  | EBS snapshot -> `aws ec2 modify-volume --size NEW_SIZE_GB` |
| `rollout-restart-then-tail.tensor9.tf`    | Rolling restart of Deployment -> `sleep 10` -> `kubectl logs --tail=N` smoke test |
| `pre-deploy-backup.tensor9.tf`            | EBS snapshot of DB -> scale API to 0 -> write deploy-in-progress flag to SSM Parameter Store |

Every template here declares the providers it needs in
`required_providers`, validates its string identifier inputs with regex
constraints, and carries one `tensor9_command "this"` block whose `name`
matches the filename stem.

## See also

- `../aws/` — building-block AWS templates these compose from.
- `../k8s/` — building-block Kubernetes templates these compose from.
