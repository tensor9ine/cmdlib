# AWS ops command templates

`.tensor9.tf` templates that target AWS resources directly (EC2, EBS, S3, RDS,
IAM). Each file is a self-contained OpenTofu module that the Tensor9 actuator
can `tofu apply` to execute one operations command on a vendor's appliance
account.

## Credential pattern

Every template declares an empty `provider "aws" {}` (or one with only
`region = var.REGION`). **No `access_key` / `secret_key` / `profile` is
hard-coded** — that is intentional.

Before the actuator runs `tofu apply`, it injects short-lived AWS credentials
into the process environment:

| Env var                 | What it carries                              |
| ----------------------- | -------------------------------------------- |
| `AWS_ACCESS_KEY_ID`     | Short-lived STS access key                   |
| `AWS_SECRET_ACCESS_KEY` | Matching secret                              |
| `AWS_SESSION_TOKEN`     | STS session token (creds are session creds)  |
| `AWS_REGION`            | Default region for the appliance deployment  |

The Hashicorp AWS provider reads these env vars natively, so an empty provider
block "just works." The pattern matches what a vendor would experience running
`tofu apply` locally with their AWS CLI already logged in — no template edits
are needed when the credentials change.

## Templates in this directory

### Read-only (no side effects)
| File                                      | What it does                                                            |
| ----------------------------------------- | ----------------------------------------------------------------------- |
| `find-idle-instances.tensor9.tf`          | List running EC2 instances with avg CPU% below a threshold over 24h     |
| `list-old-snapshots.tensor9.tf`           | List EBS snapshots older than N days, owned by this account             |
| `find-untagged-resources.tensor9.tf`      | List EC2 instances + EBS volumes missing a required tag (e.g. `Owner`)  |
| `find-unused-security-groups.tensor9.tf`  | List security groups not attached to any ENI                            |
| `list-public-s3-buckets.tensor9.tf`       | List S3 buckets whose ACL grants public READ/WRITE                      |

### Mutating (declares `side_effects`)
| File                                      | What it does                                                            |
| ----------------------------------------- | ----------------------------------------------------------------------- |
| `snapshot-ebs-volume.tensor9.tf`          | Take a point-in-time EBS snapshot of a volume                           |
| `rotate-iam-access-key.tensor9.tf`        | Mint a new IAM access key + mark the old one Inactive                   |
| `terminate-stopped-instances.tensor9.tf`  | Terminate EC2 instances that have been stopped for >= N days            |
| `rds-snapshot.tensor9.tf`                 | Take a manual RDS snapshot of a DB instance                             |

## Conventions

- The filename stem must equal `tensor9_command.this.name` so the actuator can
  resolve a template by command name without parsing HCL.
- Every string identifier variable carries a `validation` block with a regex —
  the actuator forwards user input as `-var` and we don't want to rely on
  AWS-side validation for safety.
- Mutating templates set `side_effects = [...]` so the UI can require an
  explicit confirmation before running.
- `data_access` is a categorical hint (`Infrastructure`, `Storage`, `Metrics`,
  ...) used for permission gating in the vendor portal.

## See also

- `../orchestration/` — cross-provider templates that combine AWS + Kubernetes
  (e.g. drain a node *and* snapshot its EBS volume in one command).
- `../k8s/` — pure Kubernetes ops commands.
- `../linux/` — read-only diagnostic commands that don't touch a cloud provider.
