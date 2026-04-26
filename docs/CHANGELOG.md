# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.4.5] - 2026-04-27

### Fixed
- **Gateway died when the terminal that ran `openclaw setup` was closed.** User report: setup → "Restart" → dashboard opened from setup's "Open Web UI" worked once, but reopening the dashboard after closing the setup terminal returned `ERR_CONNECTION_REFUSED`. Root cause: the shim spawned the gateway with `nohup … &` from inside the terminal's session. `nohup` ignores SIGHUP, but openclaw's Node runtime reinstalls signal handlers, undoing the ignore. When the terminal sent SIGHUP to its session on close, every process in that session — including the gateway — received it and exited. Verified by reproducing the exact symptom and confirming the gateway's `/proc/<pid>/stat` showed `SID == terminal-bash-pid`. Switching the spawn to `setsid …  < /dev/null` puts the gateway into a brand-new session with no controlling terminal, so terminal SIGHUP can no longer reach it. Verified after fix: `SID == gateway-pid` and the gateway survives terminal close

## [1.4.4] - 2026-04-27

### Fixed
- **Dashboard timeout after `openclaw setup` → "Restart"** — when the setup wizard finished and the user picked Restart on the "Gateway service already installed" prompt, OpenClaw's own health check failed with `gateway timeout after 10000ms` and the dashboard stopped responding entirely. Root cause: the bundled **bonjour (mDNS) plugin** can't reach a real LAN multicast group inside Docker's bridge network, so its CIAO advertiser stays in `announcing` for ~15s, then raises an unhandled promise rejection that takes the gateway HTTP server down with it (`Unhandled promise rejection: CIAO ANNOUNCEMENT CANCELLED`). Entrypoint now disables `bonjour` once on first boot — the plugin's only purpose is local-network gateway discovery, which doesn't apply to the typical container deployment. After this, the gateway restarts cleanly in ~3s instead of crashing after ~15s

### Added
- `bubblewrap` apt package — Codex CLI (`codex`) sandboxes child processes with `bwrap` and previously fell back to a vendored binary while warning at every launch. With the system package present, the warning goes away and Codex uses the standard distro-supplied sandbox

## [1.4.3] - 2026-04-26

### Fixed
- **Stale `gateway.pid` after OpenClaw's internal config-reload restart.** When the gateway detects a config change (e.g. `browser.enabled` toggled, channel auth tokens added during onboarding), it self-restarts the worker *outside* the systemctl shim — leaving `~/.openclaw/gateway.pid` pointing at a now-dead PID. Two safeguards added:
  - `stop_gateway` no longer trusts the PID file alone. It now also targets every `openclaw-gateway` process whose `ppid == 1` (i.e. an orphaned daemon — exactly the shape an internally-restarted gateway takes), while continuing to ignore workers spawned inside `gateway install --force` (whose ppid is the install command itself, never 1)
  - `entrypoint.sh` re-detects and rewrites `gateway.pid` after the browser-config writes that trigger the first internal restart, so the file is accurate from boot

### Verified
End-to-end smoke test with `CLAW_USER=neovis` + `OPENCLAW_BROWSER_ENABLED=true`:
- Fresh `compose up -d --build` → dashboard reachable on first boot, `gateway.pid` matches running gateway
- `openclaw gateway install --force` → no PID flapping, dashboard stays up
- `openclaw update --yes` → completes cleanly (the bundled `openclaw doctor` step inside update no longer needs the user to invoke it manually)
- All scenarios: PID file == running gateway PID after the operation

## [1.4.2] - 2026-04-26

### Fixed
- **Dashboard unreachable on first boot** — two compounding bugs left the gateway dead and the dashboard returning connection-reset until the user manually ran `openclaw doctor`:
  1. **Plugin runtime deps could not install.** OpenClaw lazy-installs each bundled plugin's runtime deps (`acpx`, `browser`, `bonjour`, …) by running `npm install` inside `<openclaw>/dist/extensions/<plugin>/`. The image-baked install lives in the system npm prefix (root-owned), so a non-root runtime user hits `EACCES`. We now create an `openclaw` system group at build time, chown the openclaw tree to it with mode `g+rwX` (group writable, *not* world-writable — OpenClaw refuses to load plugins from world-writable paths), and add every runtime user to that group from both the Dockerfile (`claw` build user) and `entrypoint.sh` (dynamic `CLAW_USER`). Verified: 6 plugins load on first boot.
  2. **`start_gateway` was fooled by transient `gateway install --force` workers.** The shim's `restart` handler called `start_gateway` after `stop_gateway`. The previous `pgrep -f openclaw-gateway` would match the short-lived `openclaw-gateway` worker that `gateway install --force` spawns inside its own process tree, write *that* PID to the PID file, return success without actually spawning a daemon, and the moment the install command finished the gateway vanished. `start_gateway` now anchors on the PID file (idempotent fast path) and, when it does spawn, polls `pgrep -P <launcher>` so it accepts only its own descendant — never an install/update worker.

## [1.4.1] - 2026-04-24

### Changed
- Bump bundled OpenClaw to `2026.4.22` (was `2026.4.21` in v1.4.0 — upstream released a new patch within a few hours of our build)
- Bump bundled Google Chrome on amd64 to `147.0.7727.116` (auto-picked up by fresh build)

## [1.4.0] - 2026-04-24

### Added
- **Agent CLIs pre-installed** — the image now ships `@anthropic-ai/claude-code` and `@openai/codex` installed globally via npm (land in `/var/openclaw-npm/bin`, already on `PATH`). OpenClaw recently added support for delegating turns to these CLIs; shipping them pre-installed means users can `openclaw` → "use Claude Code / Codex" without a separate setup step. No credentials are baked: running `claude` or `codex` for the first time still triggers the normal login flow
- Build args `CLAUDE_CODE_VERSION` and `CODEX_VERSION` (both default to `latest`) so CI or reproducible builds can pin the bundled versions — same pattern as `OPENCLAW_VERSION`
- Bundled versions recorded to `/etc/claude-code-version` and `/etc/codex-version` at build time for diagnostics

### Changed
- `docs/DOCKERHUB_OVERVIEW.md` and all four READMEs gain an "Agent CLIs" row
- Bundled versions table lists Claude Code + Codex alongside OpenClaw/Node/Chrome

## [1.3.2] - 2026-04-23

### Security
- Remove `PASSWORD=claw1234` from `ENV` block in the Dockerfile so the default password no longer lands in image history or `docker inspect` output (hadolint `SecretsUsedInArgOrEnv`). The value is now inlined into the build-time `useradd` + `chpasswd` step, and `entrypoint.sh` continues to re-sync with the runtime `CLAW_PASSWORD` on every boot, so behavior is unchanged

## [1.3.1] - 2026-04-23

### Fixed
- **arm64: `mimeapps.list` pointed at a missing handler** — the chromium package only ships `chromium.desktop`, but `configs/xfce4/mimeapps.list` hardcodes `google-chrome.desktop` as the handler for `text/html` and `x-scheme-handler/http(s)`. On arm64 this meant "Open link in default browser" (from XFCE, xdg-open, or any app opening URLs) silently fell back or failed. The Dockerfile now registers a minimal `google-chrome.desktop` that launches our `/usr/bin/google-chrome-stable` wrapper, whenever the real Chrome one is absent
- **`openclaw-sync-display` no longer races `openclaw update`** — the helper previously did its own `pkill -u $USER -f 'openclaw-gateway'` + `nohup` relaunch, which (a) killed `openclaw gateway install --force`'s transient workers when the `.bashrc` hook fired during an update, and (b) never refreshed `~/.openclaw/gateway.pid`. It now delegates to `systemctl --user restart openclaw-gateway.service`, so stop/start go through the shim and the PID file stays current

### Changed
- `scripts/update-dockerhub-overview.sh` pins `--platform linux/amd64` when probing Chrome version and pulls the Chromium version from the arm64 variant separately, so the Bundled Versions table gets the correct browser in each row
- `docs/CHANGELOG.md` and `TODO.md` stale-line cleanup

## [1.3.0] - 2026-04-22

### Added
- **Multi-arch support** — image now publishes both `linux/amd64` and `linux/arm64` manifests
  - `ARG TARGETARCH` splits the browser install: amd64 uses Google Chrome stable; arm64 uses `chromium` from `ppa:xtradeb/apps` (Ubuntu 24.04's own `chromium-browser` package is a snap-transition stub that does not run inside Docker)
  - Both code paths produce `/usr/bin/google-chrome-stable-real` so the `--no-sandbox` wrapper, `update-alternatives`, `mimeapps.list`, and custom `.desktop` entries work unchanged
  - arm64 images register a minimal `google-chrome.desktop` pointing to our wrapper, because the chromium package only ships `chromium.desktop` and `mimeapps.list` hardcodes the former
- `docs/DOCKERHUB_OVERVIEW.md` gains a "Supported Architectures" section

### Changed
- `scripts/openclaw-sync-display` delegates gateway restart to the systemctl shim instead of doing its own `pkill` + `nohup` — this ensures `~/.openclaw/gateway.pid` stays consistent and avoids killing install-spawned transient workers during a concurrent `openclaw update` (same class of bug as 1.2.4)
- `scripts/update-dockerhub-overview.sh` sed patterns updated for the new `(amd64)` / `(arm64)` row labels, pulls Chromium version from the arm64 variant separately

## [1.2.4] - 2026-04-22

### Added
- **`systemctl` user shim** (`scripts/systemctl-shim`) — translates OpenClaw's `systemctl --user {is-enabled,status,daemon-reload,enable,restart,start,stop,show}` calls into direct process management, so `openclaw update` and dashboard "Restart Gateway" complete end-to-end inside a container that has no systemd. Gateway unit file is auto-registered on first boot (`openclaw gateway install`), and `emit_show_properties` mirrors the systemd property output OpenClaw polls during health checks
- `/var/openclaw-npm/bin` prefixed onto `PATH` so `openclaw update`'s writable npm install takes precedence over the image-baked binary without requiring a shell restart
- `~/.openclaw/gateway.pid` — authoritative PID record written by both entrypoint and the shim's `start_gateway`; the shim's `stop_gateway` targets only this PID

### Fixed
- `openclaw update` no longer logs `Failed to refresh gateway service environment from updated install` — the shim previously used `pkill -f '^openclaw-gateway$'` which also killed transient `openclaw-gateway` workers that `gateway install --force` spawns in its own process tree; the PID-file approach protects them
- Custom `CLAW_USER` values (e.g. `neovis`) were left with a root-owned `~/.bashrc` because the named home volume pre-created `/home/${USER}` and `useradd -m` silently skipped the `/etc/skel` copy, then the entrypoint appended the display-sync snippet as root. Entrypoint now force-seeds `/etc/skel` with `cp -an` and chowns `.bashrc` after every append
- Loopback-only port bindings (`127.0.0.1`) by default in `docker-compose.yml`, with a commented LAN-exposure block documenting the risks (closes C3 of security review)
- Entrypoint validates `USER`/`PASSWORD` with strict regex + forbidden-character checks and runs the generated sudoers entry through `visudo -c` before installing it
- Gateway readiness check switched from single-probe to polling with an anchored pattern (`openclaw-gateway` exact, not `openclaw gateway` prefix) to avoid false positives on the `su -c` command line

### Security
- Gateway readiness detection pattern hardened (matches argv[0] exactly so shell launchers don't spoof a running gateway)
- `.dockerignore` + `.gitignore` added to prevent sensitive files from leaking into build context or repo

## [1.2.3] - 2026-04-13

### Changed
- Move npm global prefix from `~/.npm-global` to `/var/openclaw-npm` (outside the home volume)
  - Prevents stale user-installed `openclaw` from shadowing the image-baked version on upgrade
  - Eliminates version conflicts when switching `OPENCLAW_VERSION` or pulling a new image
  - Trade-off: clawhub-installed skills are now reset on container recreate (reinstall after upgrade)
- Entrypoint migrates legacy `# npm-global-prefix` block in `.bashrc` to the new `# openclaw-npm-prefix` block automatically

## [1.2.2] - 2026-04-01

### Added
- `.npmrc` with user-local prefix (`~/.npm-global`) so `npm install -g` works without root inside the container
- Enables OpenClaw skill installation via `clawhub` and the onboarding wizard without permission errors
- `.npmrc` included in defaults template (`/opt/openclaw-defaults/`) for volume persistence and dynamic user creation
- PATH export for `~/.npm-global/bin` in `.bashrc` via entrypoint

## [1.2.1] - 2026-03-31

### Added
- Document `OPENCLAW_VERSION` build arg in all READMEs (EN, KO, ZH, JA), Docker Hub overview, and `.env` file
  - Allows pinning a specific OpenClaw npm version at build time (e.g. `OPENCLAW_VERSION=2026.3.28`)

## [1.2.0] - 2026-03-31

### Added
- Policy-based X11 display targeting via `openclaw-sync-display` helper for seamless VNC ↔ xRDP switching
- Auto display-sync `.bashrc` hook — detects display changes when opening new terminals across sessions
- xRDP reconnection hook (`reconnectwm.sh`) for display sync on session reconnect
- `OPENCLAW_BROWSER_ENABLED` option for OpenClaw CDP browser support
- `OPENCLAW_DISPLAY_TARGET` environment variable with `auto` / `vnc` / `rdp` modes
- `OPENCLAW_X_DISPLAY` and `OPENCLAW_X_AUTHORITY` hard override environment variables

### Changed
- Entrypoint display/XAUTHORITY handling replaced with `openclaw-sync-display` helper (policy-based, lock-protected)
- VNC `xstartup` and xRDP `startwm.sh` now call `openclaw-sync-display` before desktop start
- Updated all README files (EN, KO, ZH, JA) and Docker Hub overview with new environment variables, workarounds, and file structure

## [1.1.1] - 2026-03-27

### Added
- Architecture diagrams (SVG) for all 4 languages (EN, KO, ZH, JA) with new "Architecture" section in each README

### Changed
- Reorganized project file structure into `assets/`, `docs/`, and `docs/images/` directories
  - Images and SVGs → `assets/`
  - Beginner's guides and CHANGELOG → `docs/`
  - Guide screenshots → `docs/images/` (previously `guide_images/`)
- Updated all internal references (image paths, guide links) across READMEs and guide files

## [1.1.0] - 2026-03-26

### Added
- `.env` file as a single source of truth for user configuration (`CLAW_USER`, `CLAW_PASSWORD`)
- Dynamic user creation at container startup — custom usernames now work without rebuild issues
- Runtime password synchronization — password changes take effect without rebuilding the image
- User config templates saved to `/opt/openclaw-defaults/` for new user initialization

### Changed
- `docker-compose.yml` now references `.env` variables (`${CLAW_USER}`, `${CLAW_PASSWORD}`) for environment and volume path
- `entrypoint.sh` creates the Linux user dynamically if it doesn't exist, copies default configs, and syncs password on every start
- Updated all README files (EN, KO, ZH, JA) with `.env` usage instructions, updated environment variable tables, and file structure
- Updated all Beginner's Guide files (EN, KO, ZH, JA) to mention `.env` for password customization

### Fixed
- Changing `USER` in docker-compose.yml no longer causes login failures (user is now created at runtime)
- Changing `PASSWORD` now applies to both VNC and RDP/sudo login (previously only VNC was updated at runtime)
- XFCE panels (menu bar, dock) now appear correctly for new users — system defaults are copied before wallpaper config to prevent XFCE from skipping first-run panel initialization

## [1.0.0] - 2026-03-25

### Added
- Initial Docker setup: Ubuntu 24.04 + XFCE4 + TigerVNC + NoVNC + xRDP
- Google Chrome with `--no-sandbox` wrapper as default browser
- Node.js 22 and OpenClaw pre-installed via npm
- OpenClaw Gateway auto-start in entrypoint
- Desktop shortcuts: OpenClaw Setup, Dashboard, Terminal
- Default `openclaw.json` config with Gateway on port 18789
- `xdg-open` wrapper to rewrite Docker internal IPs to localhost
- 3-tier VNC password fallback: `vncpasswd` binary, `openssl`, pure Python DES
- Desktop wallpaper auto-configuration for VNC and RDP monitors
- Data persistence via `openclaw-home` named volume
- Beginner's guides with screenshots in 4 languages (EN, KO, ZH, JA)
- README documentation in 4 languages (EN, KO, ZH, JA)
