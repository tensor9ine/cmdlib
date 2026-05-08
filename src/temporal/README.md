# Temporal ops command templates

Tensor9 `cmd` templates for inspecting and intervening in
[Temporal](https://temporal.io/) workflow executions — list, describe,
terminate, reset, and signal running or failed workflows.

## Why a dedicated directory

Temporal is the durable-execution platform that a large fraction of customer
applications use to coordinate long-running, multi-step business logic
(payment pipelines, provisioning flows, ETL fan-out, etc.). When a workflow
gets wedged — a non-retryable activity error, a deadlocked decision task, a
misrouted signal — SREs need first-class runbook entries for the standard
recovery moves. These templates are those entries: each one is a single
parameterized op an on-call engineer can fire from the Tensor9 console
without copy-pasting `tctl` invocations from a wiki.

## Execution model

There is no stable Hashicorp Terraform provider for Temporal runtime ops, so
each template is a `null_resource` whose `local-exec` provisioner shells out
to the **`tctl`** CLI (or the newer **`temporal`** CLI v1.18+, which is
drop-in compatible for these subcommands). The Tensor9 actuator host already
has the binary on `PATH`.

Authentication is via Temporal's standard ambient environment variables —
the same ambient-creds pattern used by `../aws/`:

| Variable                     | Purpose                                  |
| ---------------------------- | ---------------------------------------- |
| `TEMPORAL_ADDRESS`           | gRPC frontend host:port                  |
| `TEMPORAL_NAMESPACE`         | default namespace (overridable per op)   |
| `TEMPORAL_TLS_CERT`          | client cert for mTLS (Temporal Cloud)    |
| `TEMPORAL_TLS_KEY`           | client key for mTLS                      |
| `TEMPORAL_TLS_CA`            | CA bundle for self-hosted clusters       |

These templates are agnostic to **Temporal Cloud vs self-hosted** — point
`TEMPORAL_ADDRESS` at the right cluster and the same op works in either
environment.

## Templates

| Template                          | Mode      | Purpose                                                           |
| --------------------------------- | --------- | ----------------------------------------------------------------- |
| `list-running-workflows.tf`       | read-only | List workflows currently in the Running state                     |
| `describe-workflow.tf`            | read-only | Drill into a single workflow's history, pending activities, state |
| `list-failed-workflows.tf`        | read-only | List Failed/TimedOut/Terminated workflows in last N hours         |
| `terminate-workflow.tf`           | mutating  | Force-end a wedged workflow (no cleanup handlers run)             |
| `reset-workflow.tf`               | mutating  | Rewind a workflow to a prior event ID and re-run from there       |
| `signal-workflow.tf`              | mutating  | Deliver a named signal + JSON payload to a running workflow       |

## Related directories

- `../linux/` — general appliance-host diagnostics (log tails, process info)
  for when the issue is on the actuator side rather than inside Temporal.
- `../k8s/` — Kubernetes ops; relevant if Temporal itself is self-hosted on
  EKS and the frontend / matching / history pods are unhealthy.
- `../aws/` — same ambient-creds pattern, useful as a reference for how
  these templates handle auth without explicit provider blocks.
