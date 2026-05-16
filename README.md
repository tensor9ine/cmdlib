# cmdlib

`cmdlib` is the open-source reference library of operational commands
for [Tensor9](https://tensor9.com). Each command is a small Terraform
template (`*.tensor9.tf`) that runs against a customer's self-hosted
appliance through Tensor9's signed-approval workflow.

Register the repo as a template source and your customers get a vetted
catalog of read-only diagnostics and routine SRE actions on day one. The
templates are Apache 2.0 licensed, so you can fork, curate, or layer
your own app-specific commands on top.

## Table of contents

- [What is an "ops command"?](#what-is-an-ops-command)
- [Categories](#categories)
- [Vendors: register cmdlib against your app](#vendors-register-cmdlib-against-your-app)
- [Customers: what you'll see](#customers-what-youll-see)
- [Anatomy of a template](#anatomy-of-a-template)
- [Variables](#variables)
- [Read-only vs mutating](#read-only-vs-mutating)
- [Keeping cmdlib in sync](#keeping-cmdlib-in-sync)
- [Forking and curating](#forking-and-curating)
- [Contributing](#contributing)

## What is an "ops command"?

A Tensor9 appliance runs inside a customer's own cloud account. The
vendor has no SSH, no kubectl context, no AWS credentials into that
account. When something needs investigating or fixing (a stuck pod, a
disk filling up, a stale EBS snapshot to prune), the vendor submits an
**ops command**: a request to run one specific operation, defined by a
template, against one specific appliance.

The customer reviews the request through a web link (template body,
declared data-access tags, the operator's reason, the exact variable
values), approves or rejects it, and only then does the command execute
inside their appliance. Output is encrypted on the appliance and held
there until the customer signs a release.

`cmdlib` ships the **templates** (the runnable definitions). The
control plane handles approval, execution, encryption, and release.

For the underlying mechanics see Tensor9's
[Operations docs](https://docs.tensor9.com/fundamentals/operations).

## Categories

Templates are grouped by target. Every `.tensor9.tf` file under `src/`
is one template; the directory name becomes a category prefix when the
template is registered.

| Category | Use when | Examples |
|---|---|---|
| [`src/linux/`](src/linux) | Triaging a Linux appliance host. Read-only diagnostics. | `host-info`, `disk-usage`, `top-processes`, `tail-app-log`, `journalctl-tail` |
| [`src/darwin/`](src/darwin) | Triaging a macOS appliance host. Read-only diagnostics. | `host-info`, `disk-usage`, `top-processes`, `log-tail`, `pmset-status` |
| [`src/k8s/`](src/k8s) | Standard SRE operations on the appliance's Kubernetes cluster (EKS). | `list-pods`, `tail-pod-logs`, `restart-deployment`, `scale-deployment`, `drain-node`, `delete-pod` |
| [`src/aws/`](src/aws) | Direct AWS resource operations (EC2, EBS, S3, RDS, IAM). | `find-idle-instances`, `snapshot-ebs-volume`, `rotate-iam-access-key`, `rds-snapshot` |
| [`src/node/`](src/node) | Debugging a Node.js process inside the appliance. | `cpu-profile`, `heap-snapshot`, `event-loop-lag`, `gc-trace` |
| [`src/temporal/`](src/temporal) | Inspecting and intervening in Temporal workflows. | `list-running-workflows`, `describe-workflow`, `signal-workflow`, `terminate-workflow` |
| [`src/orchestration/`](src/orchestration) | Multi-step compositions that combine the categories above. | `snapshot-then-restart`, `drain-then-terminate-node`, `pre-deploy-backup` |

Each category directory has its own `README.md` with the per-file
inventory, auth pattern, conventions, and trade-off notes.

## Vendors: register cmdlib against your app

> Audience: you are the vendor running a Tensor9-powered app.

Register the GitHub repo as a template source. The control plane walks
every `.tensor9.tf` under `src/` and imports each one as a versioned
template scoped to your app.

```bash
tensor9 ops template source create \
  --sourceType GitHub \
  --sourceUrl https://github.com/tensor9ine/cmdlib \
  --appName my-app \
  --sourceName cmdlib
```

Templates are imported with their directory name as a prefix, so
`linux/disk-usage.tensor9.tf` registers as `linux-disk-usage` and does
not collide with `darwin/disk-usage.tensor9.tf` (which becomes
`darwin-disk-usage`).

### Subsetting the import

If you only want a slice (say Kubernetes plus AWS templates), pass
`--dirs`:

```bash
tensor9 ops template source create \
  --sourceType GitHub \
  --sourceUrl https://github.com/tensor9ine/cmdlib \
  --appName my-app \
  --sourceName cmdlib-k8s-aws \
  --dirs src/k8s,src/aws
```

### Running a command

Once cmdlib is registered, submit a command against a customer's
appliance:

```bash
tensor9 ops command create \
  --appName my-app \
  --customerName acme-corp \
  --template linux-disk-usage \
  --vars MOUNT_PREFIX=/var/lib/myapp \
  --commandName check-acme-disk \
  --reason "investigating disk pressure on acme-corp prod-east"

# Watch the lifecycle while the customer reviews:
tensor9 ops command retrieve \
  --appName my-app \
  --commandName check-acme-disk
```

The customer is notified through the channel you've configured, reviews
the command in their support portal, and signs an approval. After
execution they sign a second release to forward the output back to you.

## Customers: what you'll see

> Audience: you are the customer whose appliance the vendor is operating.

When the vendor submits an ops command against your appliance, you
receive a `/support/<token>` link. Clicking it opens a four-step web
flow:

1. **Review.** You see the template's description, declared
   `data_access` tags (e.g. `Infrastructure`, `Logs`), the vendor's
   justification text, and the exact body that will run with your
   variable values bound in.
2. **Approve.** Approving signs an Ed25519 manifest with a key that
   lives only in your own cloud account.
3. **Execute.** The command runs inside your appliance's sandboxed
   working directory. Output is captured and encrypted with a key the
   appliance holds in your vault.
4. **Release.** You review the decrypted output (decryption happens
   inside your appliance, under your IAM) and sign a release. Only after
   the signed release does the vendor see the plaintext output.

Every command in `cmdlib` declares its scope up front. Read-only
templates (the bulk of the catalog) only emit `data_access` tags.
Mutating templates additionally declare `side_effects`, which the
approval UI surfaces prominently so you can tell at a glance whether
a command will change state.

If you want repeat usage of the same command without per-invocation
approval, you can sign a **pre-approval**: a one-time consent that
covers a specific template + variable shape against a specific
appliance, up to N runs over a validity window. See the pre-approval
section of the Tensor9 docs.

## Anatomy of a template

Every file in `cmdlib` is a self-contained OpenTofu template. The
canonical shape:

```hcl
terraform {
  required_providers {
    tensor9 = { source = "tf-providers.prod-1.tensor9.com/tensor9/tensor9", version = "~> 2.41" }
    null    = { source = "hashicorp/null",  version = "~> 3.2" }
  }
}

provider "tensor9" {
  mode = "ops"
}

variable "MOUNT_PREFIX" {
  type        = string
  default     = "/"
  description = "Only show mounts under this path prefix"
  validation {
    condition     = can(regex("^/[A-Za-z0-9/_.-]*$", var.MOUNT_PREFIX))
    error_message = "MOUNT_PREFIX must be an absolute path"
  }
}

resource "tensor9_command" "this" {
  name        = "disk-usage"
  display     = "Disk usage"
  description = "Show `df -h` for mounts under MOUNT_PREFIX. Read-only."
  icon        = "hard-drive"
  data_access = ["Infrastructure"]
}

resource "null_resource" "df" {
  provisioner "local-exec" {
    command = "df -h | awk 'NR==1 || $6 ~ /^${var.MOUNT_PREFIX}/'"
  }
}
```

Three load-bearing pieces:

- **`tensor9_command "this"`** declares the command's identity. The
  filename stem must equal `name` so the actuator can resolve a template
  by name without parsing HCL.
- **Variables** are typed inputs the operator binds at submission time.
  Always include a `validation` block with a regex for string
  identifiers; the actuator forwards user input as `-var` and we don't
  rely on downstream-tool validation for safety.
- **The actual work** lives in resources, data sources, and outputs.
  Linux templates shell out via `null_resource.local-exec`. Kubernetes
  templates use the `kubernetes` provider authed via
  `aws_eks_cluster_auth`. AWS templates use the standard `aws` provider
  with credentials supplied by the actuator at runtime.

Open any file in the repo for a concrete example. The
[Authoring templates](https://docs.tensor9.com/fundamentals/operations/templates)
doc walks through the full template grammar.

## Variables

Operators pass variables at submission time via `--vars`:

```bash
tensor9 ops command create \
  --appName my-app \
  --customerName acme-corp \
  --template k8s-tail-pod-logs \
  --vars CLUSTER=acme-prod,NAMESPACE=app,POD=api-7f9c-abc,LINES=500 \
  --commandName tail-api-pod \
  --reason "investigating 502s reported by acme support"
```

Each variable carries:

- A `type` (almost always `string` for ops; `number` for counts).
- A `description` rendered to the customer in the approval UI.
- A `validation` regex on string identifiers. This is enforced
  client-side at submission and re-enforced by the actuator before
  apply.
- Optional `default` for variables that are usually fine as-is (e.g.
  `LINES = 1000`, `NAMESPACE = "default"`).

Customers signing a **pre-approval** can attach additional `var
constraints` that narrow the vendor's accepted values (e.g.
`MOUNT_PREFIX=regex:^/opt/myapp/.*`). The vendor's per-invocation
values must satisfy both the template's validation regex and any
buyer-imposed constraints, or the command falls back to manual
approval.

## Read-only vs mutating

Templates declare their effect surface on the `tensor9_command "this"`
resource:

| Property | Meaning |
|---|---|
| `data_access = ["Infrastructure", "Logs", ...]` | What the command can read. Required on every template. |
| `side_effects = ["Restart", "Snapshot", "Delete", ...]` | What the command will mutate. Omit (or set `[]`) for read-only commands. |

The approval UI surfaces these tags prominently. Customers can write
policies that auto-approve read-only commands while still requiring
human review for anything declaring `side_effects`. Mutating templates
in `cmdlib` always declare every state-changing operation; if you fork
a template to add a side effect, declare it.

## Keeping cmdlib in sync

`cmdlib` evolves: bug fixes, new templates, hardening. Sources support
a four-bucket re-sync flow that's diff-only; nothing changes until you
explicitly opt in.

```bash
# 1. See what's drifted upstream since your last sync
tensor9 ops template source resync --sourceName cmdlib

# 2. Apply changes selectively
tensor9 ops template source upgrade --sourceName cmdlib
```

The diff buckets:

- **Modified**: a tracked template whose source file has a different
  content hash. Upgrading mints a new template version.
- **New available**: a file at HEAD that you don't yet track.
  Importing adds it as a new template.
- **Removed upstream**: a tracked template whose source file has been
  removed. `--actions retire-here` drops the source binding while the
  template itself stays live on existing customers (no surprise
  retraction of in-use commands).
- **Unchanged**: content hash matches; no action.

`upgrade` is gated and explicit. Customers don't see new template
versions until you apply the upgrade, and pre-approvals are bound to a
specific content hash so an upstream change automatically falls back to
manual approval until the customer signs the new version.

See the [Git template sources](https://docs.tensor9.com/fundamentals/operations/sources)
doc for the full resync flow.

## Forking and curating

`cmdlib` is Apache 2.0. Fork it freely:

- **Curate down**: delete categories or templates you don't want
  customers to ever see.
- **Layer up**: keep upstream `cmdlib` registered as one source, and
  register your own app-specific templates as a second source. The two
  catalogs coexist; templates are uniquely named across sources.
- **Tighten validation**: vendors often want stricter regexes on
  identifier inputs than upstream ships. A fork is the natural place.

Register your fork the same way you'd register upstream:

```bash
tensor9 ops template source create \
  --sourceType GitHub \
  --sourceUrl https://github.com/your-org/cmdlib \
  --appName my-app \
  --sourceName cmdlib-fork
```

## Contributing

We welcome PRs. The bar:

1. **New template for an existing category**: follow the conventions in
   that category's `README.md` (auth pattern, variable validation,
   filename matches `tensor9_command.this.name`). Match existing
   `data_access` tagging conventions.
2. **New category**: discuss in an issue first. New categories imply
   new conventions and shouldn't land without coordination.
3. **Bug fix or hardening**: include a one-line reproducer in the PR
   description so reviewers can confirm the fix.

Templates that mutate state (anything declaring `side_effects`) require
an extra reviewer and a dry-run plan in the PR description. The default
bias is conservative: prefer a read-only design unless the operation
genuinely cannot be expressed that way.

## License

[Apache 2.0](LICENSE).
