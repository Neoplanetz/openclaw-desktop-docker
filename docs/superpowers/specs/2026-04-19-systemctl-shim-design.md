# Design: systemd-less update & restart support for OpenClaw in Docker

**Date:** 2026-04-19
**Status:** Approved for planning
**Author:** Code review follow-up (security-review → update-flow repair)

## Problem

OpenClaw, when run inside this Docker image, cannot complete its self-update flow. The failure has three compounding causes, discovered via instrumentation (see *Verification* below):

1. **No systemd inside the container.** OpenClaw's restart path shells out to `systemctl --user restart openclaw-gateway.service`. With no systemd user instance present, the restart is a no-op and the running gateway keeps executing the old code even after `npm install` writes the new version to disk.
2. **PATH precedence shadows the updated binary.** `npm install -g openclaw@latest` (via our `.npmrc`) writes to `/var/openclaw-npm/lib/node_modules/openclaw/`. But `/usr/bin/openclaw` is a symlink to the image-baked `/usr/lib/node_modules/openclaw/` (old version), and `/usr/bin` precedes `/var/openclaw-npm/bin` for non-interactive shells (e.g. `docker exec`, cron, systemd unit files). The result: even `openclaw --version` reports the old version in those contexts.
3. **The unit file written by `openclaw gateway install` hardcodes the baked path.** `ExecStart=/usr/bin/node /usr/lib/node_modules/openclaw/dist/index.js gateway …` — so even if systemd were present, a restart would launch the stale version.

### Observed user-facing symptoms

- After `openclaw update` succeeds at the npm layer, `openclaw update status` and the web dashboard both continue to show "update available".
- Clicking "Update" in the dashboard has no lasting effect; reopening the dashboard shows the same prompt.
- `openclaw gateway restart` (the command that the dashboard's restart button likely invokes) silently no-ops.
- `openclaw gateway status` reports `Service: systemd (disabled)` and `Runtime: unknown (systemctl --user unavailable: Failed to connect to bus: No medium found)`.

## Goal

End-to-end update must be atomic and complete: after `openclaw update` (from CLI or dashboard) finishes, the running gateway process must be executing the new code and `openclaw update status` / dashboard must report "up to date".

## Non-goals

- Running a real systemd instance inside the container.
- Supporting Podman, Kubernetes, or other runtimes.
- Providing the user with systemd service management controls — we simulate enough for OpenClaw itself; we do not expose a general-purpose systemd shim.

## Design

Four components land together. Each is individually small; the combination is what produces a correct update flow.

### Component 1 — Global PATH precedence

Add to the Dockerfile:

```dockerfile
ENV PATH="/var/openclaw-npm/bin:${PATH}"
```

Rationale: ensures `/var/openclaw-npm/bin/openclaw` wins over `/usr/bin/openclaw` for every process the container spawns — `docker exec`, cron, and scripts invoked from systemd unit files alike — not only interactive login shells. The existing `.bashrc` export stays in place as a belt-and-suspenders fallback for explicit login shells.

### Component 2 — `systemctl` shim

A new file `scripts/systemctl-shim` is copied by the Dockerfile into `/usr/local/bin/systemctl-shim`, and the Dockerfile replaces the real binary once:

```dockerfile
COPY scripts/systemctl-shim /usr/local/bin/systemctl-shim
RUN chmod +x /usr/local/bin/systemctl-shim \
 && mv /usr/bin/systemctl /usr/bin/systemctl.real \
 && ln -s /usr/local/bin/systemctl-shim /usr/bin/systemctl
```

The real binary is preserved at `/usr/bin/systemctl.real` in case a future feature needs to invoke it, and so users can revert by symlinking it back.

The shim handles the following subcommands, ignoring `--user` / `--system` / `--no-pager` / `--no-page` flags uniformly:

| Subcommand | Behavior |
|---|---|
| `restart <openclaw-gateway.service>` | Kill existing gateway (see pkill pattern below) and spawn a replacement via `nohup "$OPENCLAW_BIN" gateway run` with DISPLAY/XAUTHORITY read from `~/.openclaw/.env`. |
| `start <unit>` | If no gateway process, spawn one; else no-op. |
| `stop <unit>` | Terminate gateway. |
| `is-active <unit>` | Emit `active`/`inactive` and exit 0/3 based on actual process presence. |
| `is-enabled <unit>` | Emit `enabled` if the unit file exists in `~/.config/systemd/user/`, else `disabled`. |
| `status [<unit>]` | Emit a minimal plausible status block and exit 0 if the gateway is running. Without a unit argument, emit user-manager-like lines. |
| `show <unit> --property X,Y,Z` | Emit one `KEY=value` line per requested property. Supported keys: `ActiveState`, `SubState`, `MainPID`, `ExecMainStatus`, `ExecMainCode`. **Without this, OpenClaw's health poll (11+ iterations per restart) never sees a valid `ActiveState=active`, times out, and reports "Gateway did not become healthy after restart".** |
| `enable` / `disable` / `daemon-reload` / `reset-failed` / `reload` / `kill` | No-op, exit 0. |
| `cat <unit>` | `cat ~/.config/systemd/user/<unit>` if it exists. |
| anything else | No-op, exit 0. |

Binary resolution inside the shim:

```bash
if [ -x /var/openclaw-npm/bin/openclaw ]; then
    OPENCLAW_BIN=/var/openclaw-npm/bin/openclaw
else
    OPENCLAW_BIN=/usr/bin/openclaw
fi
```

Ensures we spawn the post-update binary when it exists, and the baked binary on first boot.

Process matching — use `-f "^openclaw-gateway$"` throughout:

```bash
pkill -u "$(id -u)" -f "^openclaw-gateway$"
pgrep -u "$(id -u)" -f "^openclaw-gateway$"
```

Discovered constraints that forced this pattern:
- `-x openclaw-gateway` fails because the kernel `comm` field truncates to 15 characters (`openclaw-gatewa`).
- Bare `-f openclaw-gateway` matches shell command lines that merely contain the string, including the invoking shell itself — **this bug caused our initial shim to SIGTERM its own parent process (exit 143)**.
- Anchoring with `^…$` against `-f` matches only processes whose full command line is exactly `openclaw-gateway`.

### Component 3 — Auto-install the unit on entrypoint

OpenClaw uses the presence of `~/.config/systemd/user/openclaw-gateway.service` as the gate for whether to attempt a `systemctl restart` at all. Without the unit file, it prints "Gateway service disabled" and bails. So the shim never sees the call.

Entrypoint runs `openclaw gateway install` once per container (idempotent — OpenClaw handles the "already installed" case itself):

```bash
UNIT_FILE="/home/${USER}/.config/systemd/user/openclaw-gateway.service"
if [ ! -f "${UNIT_FILE}" ]; then
    su - "${USER}" -c "openclaw gateway install" 2>/dev/null || true
fi
```

Placement: after the gateway is started but before the "Access:" banner, so any restart triggered later in the same boot sees the unit.

### Component 4 — `lsof` in the image

OpenClaw's restart code probes port 18789 via `lsof` (and falls back to `ss`). Neither is currently installed, producing:

```
[restart] lsof failed during initial stale-pid scan for port 18789: ENOENT
Port diagnostics errors: Error: spawn lsof ENOENT; Error: spawn ss ENOENT
```

Install `lsof` in the Dockerfile apt step. Purely cosmetic — removes the noise and lets OpenClaw's own pre-restart diagnostics work.

## File-level change summary

| File | Change |
|---|---|
| `Dockerfile` | Add `ENV PATH="/var/openclaw-npm/bin:${PATH}"`; add `lsof` to apt install; `COPY scripts/systemctl-shim` and rename real `systemctl` as shown in Component 2. |
| `scripts/systemctl-shim` (new) | The shim script described above. |
| `entrypoint.sh` | Run `openclaw gateway install` once per container if the user unit file is missing (Component 3). No involvement with the shim itself — the Dockerfile handles that. |
| `README.md` + 3 translations | Replace the "Gateway daemon install will fail — ignore this" section with the new, accurate flow. The onboarding wizard's daemon step now completes cleanly. |

## Verification (already performed in-session)

Each claim above was observed in a running container. The trace shim logged the following sequence for `openclaw update --yes` after the unit file was installed and our smart shim was active:

```
restart openclaw-gateway.service  ×2
enable openclaw-gateway.service   ×1
daemon-reload                     ×1
is-enabled openclaw-gateway.service ×2
status                            ×12
show … --property ActiveState,SubState,MainPID,ExecMainStatus,ExecMainCode  ×11
```

Observed outcomes:
- Gateway PID 2831 → 3755 (process actually replaced).
- `openclaw gateway probe` before: `app 2026.4.11`. After: same (no version bump in this test because we were already at 2026.4.15), but for the first update we captured 2026.4.11 → 2026.4.15 on disk with restart succeeding.
- `openclaw update status` flipped from `available · pnpm · npm update 2026.4.15` to `pnpm · up to date · npm latest 2026.4.15`.
- `openclaw gateway restart` invoked standalone: PID 3755 → 3988.

The same `update` command without the shim produced `Restarting service... Gateway service disabled. Start with: openclaw gateway install` and the gateway PID did not change.

## Open questions (for the review pass)

1. **Should we eliminate the baked `/usr/lib/node_modules/openclaw` entirely** by changing the Dockerfile to install OpenClaw only to `/var/openclaw-npm/`? That removes the two-install-site confusion at the root. Deferred to a separate change — larger blast radius (affects first-boot latency, volume semantics) and orthogonal to the restart fix.

2. **Warning during update: "Failed to refresh gateway service environment from updated install"** — seen once, restart still completed. Likely OpenClaw attempting to probe the new binary before restart. Acceptable to leave unaddressed unless it turns out to block in some environments.

## Out of scope

- Browser-initiated update via dashboard *button*: not tested directly (requires UI automation), but the same `systemctl` calls are made regardless of trigger source — the shim handles all callers uniformly.
- `openclaw uninstall` — also shells out to systemctl; benefits from the shim but not explicitly tested.
- Running the gateway under a real supervisor (s6-overlay, tini-as-init). Possible future direction if the shim becomes too fragile across OpenClaw versions.
