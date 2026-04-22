# TODO

Deferred items from the security review and the systemctl-shim work.

## Resolved

- **Update/restart flow** — `openclaw update` and dashboard "Restart Gateway" now complete end-to-end via the `systemctl` shim (see `docs/superpowers/specs/2026-04-19-systemctl-shim-design.md`).

## Watch list

- **Shim/OpenClaw property coupling** — `scripts/systemctl-shim`'s `emit_show_properties` hardcodes the systemd property keys OpenClaw polls today (`ActiveState`, `SubState`, `MainPID`, `ExecMainStatus`, `ExecMainCode`). If a future OpenClaw release polls additional keys, the shim returns them as empty (`KEY=`) and OpenClaw's parse may fail silently. Re-verify against new OpenClaw releases when bumping `OPENCLAW_VERSION`.

## Pending

### C5 — Verify whether `seccomp=unconfined` is still required
**File:** `docker-compose.yml:48-49`

Chrome already runs through a `--no-sandbox` wrapper, so its internal
sandbox is off — the additional `seccomp=unconfined` may be redundant.
Removing it shrinks the container's syscall attack surface significantly.

**Steps:**
1. Comment out the `seccomp=unconfined` line.
2. `docker compose up -d --build`.
3. Verify: NoVNC desktop loads, Chrome opens, OpenClaw Gateway reaches
   "running ✓", a skill install via clawhub works.
4. If everything works → remove the line permanently.
5. If something breaks → restore the line and add an inline comment
   documenting *which specific feature* requires it (so the next reviewer
   doesn't re-question it).

### C4 — Optional NoVNC TLS for LAN-exposure users
**File:** `entrypoint.sh:159` (websockify launch)

Now that ports default to `127.0.0.1` (commit `7639aa1`), plaintext
NoVNC is no longer a default-config risk. But users who opt into LAN
exposure should have a turnkey TLS option.

**Sketch:**
- Auto-generate a self-signed cert at first boot if `NOVNC_TLS=1` is set.
- Pass `--cert=/etc/openclaw/novnc.crt --key=/etc/openclaw/novnc.key` to
  websockify.
- README: document `https://localhost:6080/vnc.html` + cert-trust step.
