# node — Node.js diagnostic ops templates

This directory holds `.tensor9.tf` ops command templates for **debugging
Node.js applications running inside Kubernetes pods**. Every template targets
a Node.js process specifically — Java, Python, Go, etc. equivalents would
each warrant their own sibling directory.

## When to reach for these

The operator is on call. A Node service is misbehaving — memory growth, CPU
spike, GC stalls, hung-handle leak, "did the new version actually deploy?" —
and you want to *peek inside the live process* without restarting it. These
templates extract diagnostics out of the running pod, in place. None of them
restart, scale, or otherwise disrupt the workload (the closest is
`heap-snapshot`, which writes a file to the pod's `/tmp`, and `gc-trace`,
which toggles a tracing signal).

## Execution model

Every template is identical in shape:

1. `null_resource` with `triggers = { run_at = timestamp() }` so each apply re-fires.
2. `provisioner "local-exec"` running:
   ```
   aws eks update-kubeconfig --name $CLUSTER --region <data.aws_region>
   kubectl exec $POD -n $NAMESPACE [-c $CONTAINER] -- <node-debug-command>
   ```

The actuator host already has `aws`, `kubectl`, `node`, and ambient AWS
credentials per `../aws/README.md`. We deliberately use the
`update-kubeconfig` shell-out path (matching `../k8s/tail-pod-logs.tensor9.tf`)
rather than the `data "aws_eks_cluster_auth"` + `provider "kubernetes"`
pattern, because we want a one-shot exec, not declarative state.

`cpu-profile.tensor9.tf` is the lone exception — it briefly opens the Node
inspector port (default `9229`) inside the container by sending `SIGUSR1`,
drives the inspector via the WebSocket protocol, and emits a `.cpuprofile`.
Be aware of the briefly-open inspector port if your container's network
policy is strict.

## Variable convention

| Var               | Meaning                                    | Validation                          |
|-------------------|--------------------------------------------|-------------------------------------|
| `CLUSTER`         | EKS cluster name                           | `^[A-Za-z0-9-]+$`                   |
| `POD`             | Target pod                                 | `^[a-z0-9-]+$`                      |
| `NAMESPACE`       | Kubernetes namespace (default `default`)   | `^[a-z0-9-]+$`                      |
| `CONTAINER`       | Container name (default `""` = first)      | empty OR `^[a-z0-9-]+$`             |

Per-template numeric vars (`PID`, `DURATION_SECONDS`, `LINES`, `SAMPLES`,
`DEPTH`, `INSPECTOR_PORT`) carry range validation.

## Templates

| Template                  | Purpose                                                                  | Side effects?      |
|---------------------------|--------------------------------------------------------------------------|--------------------|
| `process-info`            | Dump version, PID, uptime, memory, argv as JSON. First-touch triage.     | read-only          |
| `tail-stderr`             | Trailing N lines of a specific container's log stream.                   | read-only          |
| `event-loop-lag`          | Sample setImmediate scheduling lag N times.                              | read-only          |
| `open-handles`            | List active handles + active requests (timers, sockets, FDs).            | read-only          |
| `npm-list`                | Dump the actually-installed npm dep tree — confirms what's deployed.     | read-only          |
| `cpu-profile`             | 10s v8 CPU profile via inspector protocol. Briefly opens inspector port. | read-only-ish      |
| `heap-snapshot`           | SIGUSR2 → `.heapsnapshot` in `/tmp`. `kubectl cp` it out afterwards.     | writes pod `/tmp`  |
| `gc-trace`                | SIGUSR1 toggle GC tracing for N seconds (requires app cooperation).      | toggles tracing    |

## See also

- `../k8s/` — pod-level ops: restart deployment, scale, drain, etc.
- `../linux/` — appliance-host diagnostics that don't reach into Kubernetes.
- `../orchestration/` — multi-step workflows that may chain these together
  (e.g., "if event-loop-lag > N, capture heap snapshot then restart").
