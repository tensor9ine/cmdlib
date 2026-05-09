# darwin — macOS appliance-host diagnostics

Read-only `.tensor9.tf` ops command templates for triaging an appliance host
running macOS (the **bx**) directly. Each template wraps a standard macOS
diagnostic — log tails, process listings, disk usage, network sockets,
launchd jobs, power state — in a `tensor9_command` resource so it can be
fired from the ops console.

These mirror the `linux/` set where it makes sense (`host-info`,
`disk-usage`, `top-processes`, `network-connections`, `tail-app-log`) and
add macOS-specific equivalents where the Linux command has no direct
counterpart (`log-tail` replaces `dmesg-tail` / `journalctl-tail`,
`disk-list` exposes `diskutil list`, `launchd-list` mirrors a systemd
service inventory).

## Execution model

Every template in this directory uses the same shape:

- `terraform { required_providers { tensor9, null } }` — no AWS, no Kubernetes.
- A `tensor9_command "this"` resource carrying the name, display, description,
  icon, and `data_access` tags.
- A `null_resource` with a `local-exec` provisioner that shells out on the
  **actuator host** (the bx itself).

Because the actuator runs in the appliance's own shell, no cloud provider
auth is involved. The standard macOS toolchain is assumed to be on `PATH`:
`uname`, `uptime`, `vm_stat`, `sw_vers`, `system_profiler`, `df`, `top`,
`lsof`, `log`, `diskutil`, `launchctl`, `pmset`, `tail`.

## When to reach for these

These are the first commands to fire when picking up an unfamiliar macOS
appliance or chasing an alert without a clear cause. They answer "is the
box healthy?" "what's running?" "what's the system log saying?" — before
you reach for AWS-side data plane queries or app-specific tooling.

`host-info` is a particularly good first call: one shot, no parameters,
gives you kernel / uptime / memory pressure / OS release / hardware
overview in a single pane.

## Templates

| Template | Purpose | Variables |
|---|---|---|
| `host-info` | uname + uptime + vm_stat + sw_vers + system_profiler hardware | — |
| `disk-usage` | `df -h` filtered by mount prefix | `MOUNT_PREFIX` |
| `disk-list` | `diskutil list` — partition layout / volume types | — |
| `top-processes` | `top -l 1` snapshot, sorted by cpu or mem | `SORT_BY`, `LIMIT` |
| `network-connections` | `lsof -i -n -P` (tcp / udp / both) | `PROTO` |
| `log-tail` | `log show --last <window>` with optional predicate | `WINDOW`, `PREDICATE` |
| `launchd-list` | `launchctl list` filtered by label substring | `FILTER` |
| `system-profile` | `system_profiler <SPDataType>` for any data type | `DATA_TYPE` |
| `pmset-status` | `pmset -g` / `-g batt` / `-g assertions` / `-g log` tail | — |
| `tail-app-log` | `tail -n <lines>` on a file under allowed log roots | `PATH`, `LINES` |

## Conventions

- **Read-only by default.** No template here mutates state. Mutating
  templates belong in `orchestration/` or app-specific dirs.
- **`data_access` tags** match the `linux/` set: `Infrastructure`,
  `Filesystem`, `Logs`. Add new tags only when the existing ones don't
  cover what the cmd touches.
- **`PATH` validation** on `tail-app-log` restricts reads to the conventional
  macOS log roots (`/Library/Logs`, `/var/log`, `/tmp`, `~/Library/Logs`).
  Buyers can narrow further at pre-approval time.
- **`PREDICATE` on `log-tail`** is operator-supplied and passed verbatim to
  `log show --predicate`. Unify-logging predicates are powerful (process,
  subsystem, category, severity); see `man log` for the full grammar.
