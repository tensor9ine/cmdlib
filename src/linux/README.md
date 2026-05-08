# linux — appliance-host diagnostics

Read-only `.tensor9.tf` ops command templates for triaging an appliance host
(the **bx**) directly. Each template wraps a standard Linux diagnostic — log
tails, process listings, disk usage, network sockets, kernel ring buffer — in
a `tensor9_command` resource so it can be fired from the ops console.

## Execution model

Every template in this directory uses the same shape:

- `terraform { required_providers { tensor9, null } }` — no AWS, no Kubernetes.
- A `tensor9_command "this"` resource carrying the name, display, description,
  icon, and `data_access` tags.
- A `null_resource` with a `local-exec` provisioner that shells out on the
  **actuator host** (the bx itself).

Because the actuator runs in the appliance's own shell, no cloud provider
auth is involved. The standard appliance toolchain is assumed to be on
`PATH`: `ps`, `df`, `ss`, `dmesg`, `journalctl`, `tail`, `awk`, `uname`,
`uptime`, `free`, `lsb_release`.

## When to reach for these

These are the first commands to fire when picking up an unfamiliar appliance
or chasing an alert without a clear cause. They answer "is the box healthy?"
"what's running?" "what's the kernel saying?" — before you reach for
AWS-side data plane queries or `kubectl`.

`host-info` is a particularly good first call: one shot, no parameters,
returns kernel + uptime + memory + distro all at once.

## Output cap

The bx caps captured stdout at **4 MiB** per command invocation. Any template
that could plausibly produce more than that — `dmesg`, `journalctl`, log
tails — exposes a `LINES` (or `LIMIT`) variable with a hard upper bound, and
pipes through `tail` / `head` so the cap is never the thing doing the
truncating. Don't add an unbounded `cat` of a log file here.

## Templates

| Template                       | What it does                                                            |
| ------------------------------ | ----------------------------------------------------------------------- |
| `host-info.tensor9.tf`         | uname + uptime + free + distro release in one shot. No vars.            |
| `tail-app-log.tensor9.tf`      | Tail last `LINES` of a log file under `/var/log/`.                      |
| `disk-usage.tensor9.tf`        | `df -h` filtered to mounts under `MOUNT_PREFIX`.                        |
| `top-processes.tensor9.tf`     | Top `LIMIT` processes by `cpu` or `memory`.                             |
| `network-connections.tensor9.tf` | `ss -tunap` listing open sockets, optionally filtered by `STATE`.     |
| `dmesg-tail.tensor9.tf`        | Last `LINES` of the kernel ring buffer (`dmesg`).                       |
| `journalctl-tail.tensor9.tf`   | `journalctl -u UNIT --since SINCE -n LINES` for a systemd unit.         |

All templates are read-only. None mutate host state.
