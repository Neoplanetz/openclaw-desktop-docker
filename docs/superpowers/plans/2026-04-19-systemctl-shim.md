# systemd-less OpenClaw Update & Restart — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `openclaw update` and `openclaw gateway restart` complete cleanly inside the container, so the dashboard's "update available" / "restart" flows end in an up-to-date running gateway instead of silently leaving old code in memory.

**Architecture:** A `systemctl` shim intercepts the systemd-user calls OpenClaw makes, translating them into direct process management (`pkill` + `nohup openclaw gateway run`). The Dockerfile renames the real `systemctl` and symlinks the shim in its place. A global `PATH=/var/openclaw-npm/bin:...` ensures the post-update binary wins over the image-baked one. The entrypoint runs `openclaw gateway install` once per container so the unit file exists — without it, OpenClaw's restart path short-circuits to "Gateway service disabled" before the shim is ever called.

**Tech Stack:** Bash (shim + entrypoint), Dockerfile, existing OpenClaw CLI (`openclaw gateway install`, `openclaw update`).

**Spec reference:** `docs/superpowers/specs/2026-04-19-systemctl-shim-design.md`

---

## File Structure

| File | Role | Create/Modify |
|---|---|---|
| `scripts/systemctl-shim` | The shim script itself. Handles `restart/start/stop/is-active/is-enabled/status/show/cat/enable/disable/daemon-reload/…` for `openclaw-gateway.service`. | Create |
| `Dockerfile` | Add `ENV PATH`, install `lsof`, COPY shim, swap real `systemctl` for shim. | Modify |
| `entrypoint.sh` | Call `openclaw gateway install` once per container if the user unit file is missing. | Modify |
| `README.md`, `README.ko.md`, `README.ja.md`, `README.zh.md` | Replace "Gateway daemon will fail — ignore" with the new, accurate onboarding flow. | Modify |
| `TODO.md` | Close out the "update flow" item by removing/reclassifying once verified. | Modify |
| `docs/superpowers/plans/2026-04-19-systemctl-shim.md` | This plan. | Already exists |

---

## Task 1: Write the `systemctl` shim script

**Files:**
- Create: `scripts/systemctl-shim`

- [ ] **Step 1: Create `scripts/systemctl-shim` with full content**

```bash
#!/bin/bash
# ============================================================
# systemctl-shim — translate systemd-user calls to direct
# process management for OpenClaw inside a Docker container.
#
# The container has no systemd user instance, so OpenClaw's
# built-in `systemctl --user restart openclaw-gateway.service`
# path is a dead end. This shim intercepts the calls OpenClaw
# actually makes during `openclaw update` and `openclaw gateway
# restart`, killing the running gateway and spawning a fresh
# one via `openclaw gateway run`, and emits the property output
# that OpenClaw's health-polling loop expects.
#
# Scope: only `openclaw-gateway.service` is handled specially.
# Everything else returns success (exit 0) silently, since a
# container without systemd cannot honor generic systemd calls.
# The real binary is preserved at /usr/bin/systemctl.real in
# case a future feature needs it.
# ============================================================
set -u

LOG="/tmp/systemctl-shim.log"
# Best-effort trace; never break callers on log-write failure.
{ echo "[$(date +%H:%M:%S)] systemctl $* (uid=$(id -u))" >> "$LOG"; } 2>/dev/null || true

# Strip systemd flags that don't affect our dispatch.
ARGS=()
for a in "$@"; do
    case "$a" in
        --user|--system|--no-pager|--no-page|--quiet) ;;
        *) ARGS+=("$a") ;;
    esac
done
set -- ${ARGS[@]+"${ARGS[@]}"}

CMD="${1:-}"
UNIT="${2:-}"

# Prefer post-update binary; fall back to baked image binary.
resolve_openclaw_bin() {
    if [ -x /var/openclaw-npm/bin/openclaw ]; then
        echo "/var/openclaw-npm/bin/openclaw"
    else
        echo "/usr/bin/openclaw"
    fi
}

# Anchored match: argv[0] must be exactly "openclaw-gateway".
# Avoids matching shell command lines like `bash -c '... openclaw-gateway ...'`,
# which SIGTERMed our own shell in earlier iterations.
GW_PATTERN='^openclaw-gateway$'

gateway_pid() {
    pgrep -u "$(id -u)" -f "$GW_PATTERN" 2>/dev/null | head -1
}

unit_file() {
    echo "${HOME:-/home/$(id -un)}/.config/systemd/user/${1:-openclaw-gateway.service}"
}

start_gateway() {
    [ -n "$(gateway_pid)" ] && return 0
    local bin env_file DISPLAY_VAL XAUTH log
    bin=$(resolve_openclaw_bin)
    env_file="${HOME}/.openclaw/.env"
    DISPLAY_VAL=":1"
    XAUTH="${HOME}/.Xauthority"
    if [ -f "$env_file" ]; then
        local d x
        d=$(grep '^DISPLAY=' "$env_file" 2>/dev/null | cut -d= -f2)
        x=$(grep '^XAUTHORITY=' "$env_file" 2>/dev/null | cut -d= -f2)
        [ -n "$d" ] && DISPLAY_VAL="$d"
        [ -n "$x" ] && XAUTH="$x"
    fi
    log="${HOME}/.openclaw/gateway.log"
    mkdir -p "${HOME}/.openclaw" 2>/dev/null || true
    DISPLAY="$DISPLAY_VAL" XAUTHORITY="$XAUTH" \
        nohup "$bin" gateway run >> "$log" 2>&1 &
    disown 2>/dev/null || true
    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do
        sleep 1
        [ -n "$(gateway_pid)" ] && return 0
    done
    return 1
}

stop_gateway() {
    pkill -u "$(id -u)" -f "$GW_PATTERN" 2>/dev/null
    local i
    for i in 1 2 3 4 5; do
        sleep 1
        [ -z "$(gateway_pid)" ] && return 0
    done
    pkill -9 -u "$(id -u)" -f "$GW_PATTERN" 2>/dev/null
    sleep 1
    return 0
}

emit_show_properties() {
    # Parse the --property argument (either `--property=X,Y` or
    # `--property X,Y`). systemd accepts both.
    local props=""
    local i=1
    while [ "$i" -le "$#" ]; do
        local arg; arg=$(eval "echo \${$i}")
        case "$arg" in
            --property=*) props="${arg#--property=}" ;;
            --property)
                i=$((i + 1))
                props=$(eval "echo \${$i}")
                ;;
        esac
        i=$((i + 1))
    done
    [ -z "$props" ] && props="ActiveState,SubState,MainPID,ExecMainStatus,ExecMainCode"

    local pid active sub main
    pid=$(gateway_pid)
    if [ -n "$pid" ]; then
        active="active"; sub="running"; main="$pid"
    else
        active="inactive"; sub="dead"; main="0"
    fi

    local p
    IFS=',' read -ra PROP_ARR <<< "$props"
    for p in "${PROP_ARR[@]}"; do
        case "$p" in
            ActiveState)     echo "ActiveState=$active" ;;
            SubState)        echo "SubState=$sub" ;;
            MainPID)         echo "MainPID=$main" ;;
            ExecMainStatus)  echo "ExecMainStatus=0" ;;
            ExecMainCode)    echo "ExecMainCode=0" ;;
            *)               echo "$p=" ;;
        esac
    done
}

case "$CMD" in
    restart)
        case "$UNIT" in
            *openclaw-gateway*) stop_gateway; start_gateway; exit $? ;;
        esac
        exit 0 ;;
    start)
        case "$UNIT" in
            *openclaw-gateway*) start_gateway; exit $? ;;
        esac
        exit 0 ;;
    stop)
        case "$UNIT" in
            *openclaw-gateway*) stop_gateway; exit $? ;;
        esac
        exit 0 ;;
    is-active)
        case "$UNIT" in
            *openclaw-gateway*)
                if [ -n "$(gateway_pid)" ]; then echo active; exit 0
                else echo inactive; exit 3; fi ;;
        esac
        echo active; exit 0 ;;
    is-enabled)
        case "$UNIT" in
            *openclaw-gateway*)
                if [ -f "$(unit_file openclaw-gateway.service)" ]; then
                    echo enabled; exit 0
                else
                    echo disabled; exit 1
                fi ;;
        esac
        echo enabled; exit 0 ;;
    status)
        if [ -z "$UNIT" ]; then
            echo "● user@$(id -u).service - User Manager"
            echo "     Loaded: loaded"
            echo "     Active: active (running)"
            exit 0
        fi
        case "$UNIT" in
            *openclaw-gateway*)
                if [ -n "$(gateway_pid)" ]; then
                    echo "● $UNIT - OpenClaw Gateway"
                    echo "     Active: active (running)"
                    echo "   Main PID: $(gateway_pid)"
                    exit 0
                else
                    echo "● $UNIT"
                    echo "     Active: inactive (dead)"
                    exit 3
                fi ;;
        esac
        exit 0 ;;
    show)
        # shift off "show" and the unit name so emit_show_properties sees only flags.
        shift 2 2>/dev/null || true
        emit_show_properties "$@"
        exit 0 ;;
    cat)
        local_unit=$(unit_file "$UNIT")
        [ -f "$local_unit" ] && cat "$local_unit"
        exit 0 ;;
    enable|disable|daemon-reload|reset-failed|reload|reload-or-restart|kill|preset|mask|unmask)
        exit 0 ;;
    "")
        exit 0 ;;
    *)
        exit 0 ;;
esac
```

- [ ] **Step 2: Make the shim executable**

Run: `chmod +x scripts/systemctl-shim`

- [ ] **Step 3: Bash syntax check**

Run: `bash -n scripts/systemctl-shim && echo OK`
Expected: `OK`

- [ ] **Step 4: Smoke-test dispatch on the host (without openclaw present)**

Run:
```bash
scripts/systemctl-shim --user is-enabled openclaw-gateway.service; echo "exit=$?"
scripts/systemctl-shim --user show openclaw-gateway.service --property ActiveState,SubState,MainPID
scripts/systemctl-shim --user enable foo; echo "exit=$?"
```
Expected (host has no unit file and no gateway running):
```
disabled
exit=1
ActiveState=inactive
SubState=dead
MainPID=0
exit=0
```
The point: the script runs end-to-end without errors, returns expected exit codes, and produces parseable property output.

- [ ] **Step 5: Commit**

```bash
git add scripts/systemctl-shim
git commit -m "feat: add systemctl shim for systemd-less OpenClaw gateway restart

Translates the systemd-user calls OpenClaw issues during update and
restart flows into direct process management. Covers restart/start/
stop/is-active/is-enabled/status/show/cat and silently no-ops the
rest. Emits realistic ActiveState/SubState/MainPID property output
so OpenClaw's health-polling loop resolves instead of timing out.

See docs/superpowers/specs/2026-04-19-systemctl-shim-design.md."
```

---

## Task 2: Wire the shim into the Dockerfile

**Files:**
- Modify: `Dockerfile`

- [ ] **Step 1: Add `ENV PATH` so `/var/openclaw-npm/bin` precedes `/usr/bin`**

In `Dockerfile`, locate the existing ENV block (lines 10-24) that ends with `OPENCLAW_DISPLAY_TARGET=auto`. Replace it with:

```dockerfile
# ── Environment variables ──────────────────────────────────────────────
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=ko_KR.UTF-8 \
    LANGUAGE=ko_KR:ko \
    LC_ALL=ko_KR.UTF-8 \
    TZ=Asia/Seoul \
    USER=claw \
    PASSWORD=claw1234 \
    VNC_PORT=5901 \
    NOVNC_PORT=6080 \
    RDP_PORT=3389 \
    DISPLAY=:1 \
    VNC_RESOLUTION=1920x1080 \
    VNC_COL_DEPTH=24 \
    OPENCLAW_DISPLAY_TARGET=auto \
    PATH=/var/openclaw-npm/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

Rationale: without explicit `PATH`, Docker's default is `/usr/local/sbin:…:/bin`. Post-update the binary lives at `/var/openclaw-npm/bin/openclaw`; without this prepend, non-interactive shells resolve `/usr/bin/openclaw` (the baked version) instead.

- [ ] **Step 2: Add `lsof` to the apt install list**

In `Dockerfile`, locate `net-tools \` in the apt install block (around line 59) and add `lsof \` on the line after it:

```dockerfile
    net-tools \
    lsof \
    ca-certificates \
```

Rationale: OpenClaw uses `lsof` to probe whether port 18789 is already in use before/after restart. Without it, update output is noisy (`Error: spawn lsof ENOENT`).

- [ ] **Step 3: COPY the shim and swap the real binary**

In `Dockerfile`, locate this block (after the existing `COPY scripts/openclaw-sync-display …` block, around line 200):

```dockerfile
# ── Display sync helper (policy-based display targeting) ─────
COPY scripts/openclaw-sync-display /usr/local/bin/openclaw-sync-display
RUN chmod +x /usr/local/bin/openclaw-sync-display
```

Immediately after it, insert:

```dockerfile
# ── systemctl shim (real systemd is not present inside the container) ─
# Intercepts the `systemctl --user …` calls that OpenClaw makes during
# `openclaw update` and `openclaw gateway restart` and translates them
# into direct pkill+nohup management of the gateway process.
# The real binary is preserved at /usr/bin/systemctl.real for escape.
COPY scripts/systemctl-shim /usr/local/bin/systemctl-shim
RUN chmod +x /usr/local/bin/systemctl-shim \
    && mv /usr/bin/systemctl /usr/bin/systemctl.real \
    && ln -s /usr/local/bin/systemctl-shim /usr/bin/systemctl
```

- [ ] **Step 4: Verify the edits by reading them back**

Run:
```bash
grep -n "PATH=/var/openclaw-npm" Dockerfile
grep -n "lsof \\\\" Dockerfile
grep -n "systemctl-shim" Dockerfile
```
Expected: each grep prints at least one matching line number.

- [ ] **Step 5: Commit**

```bash
git add Dockerfile
git commit -m "feat: install systemctl shim and make PATH prefer user-prefix openclaw

Add ENV PATH so /var/openclaw-npm/bin precedes /usr/bin in all
container processes (not only interactive login shells). Install
lsof so OpenClaw's port-probe diagnostics work. COPY the shim,
move the real systemctl to /usr/bin/systemctl.real, and symlink
/usr/bin/systemctl to the shim."
```

---

## Task 3: Auto-install the gateway unit file on first boot

**Files:**
- Modify: `entrypoint.sh`

- [ ] **Step 1: Locate the post-gateway-start block**

Open `entrypoint.sh` and find the block that begins with `echo ">> Starting OpenClaw Gateway..."` (around line 313 — search for it). Find the end of the success branch — the line that reads `echo "Browser : enabled (profile: openclaw, noSandbox: true)"` inside `if [ "${OPENCLAW_BROWSER_ENABLED}" = "true" ]`. The block we modify sits between the gateway-running check and the browser-config check.

- [ ] **Step 2: Insert the unit-file auto-install step**

Find this exact sequence in `entrypoint.sh` (it exists inside the `if [ "${GATEWAY_READY}" = "true" ]` branch):

```bash
    if [ "${GATEWAY_READY}" = "true" ]; then
        echo "Gateway : running ✓"
        echo "Dashboard: http://localhost:18789/"
        echo ""
        echo "  Set AI model via Dashboard if not configured"
```

Replace that sequence with:

```bash
    if [ "${GATEWAY_READY}" = "true" ]; then
        echo "Gateway : running ✓"
        echo "Dashboard: http://localhost:18789/"
        echo ""
        echo "  Set AI model via Dashboard if not configured"

        # ── systemd user unit registration ────────────────────
        # Without this unit file, OpenClaw's restart flow short-circuits
        # to "Gateway service disabled" before our systemctl shim sees
        # the call. We install it once per container; subsequent updates
        # reuse the existing file.
        UNIT_FILE="/home/${USER}/.config/systemd/user/openclaw-gateway.service"
        if [ ! -f "${UNIT_FILE}" ]; then
            echo ">> Registering OpenClaw gateway unit file..."
            su - "${USER}" -c "openclaw gateway install" >/dev/null 2>&1 || \
                echo "   (unit registration reported a non-fatal error; continuing)"
        fi
```

- [ ] **Step 3: Syntax check**

Run: `bash -n entrypoint.sh && echo OK`
Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add entrypoint.sh
git commit -m "feat: auto-register openclaw gateway unit file on first boot

OpenClaw's restart flow (systemctl --user restart openclaw-gateway
.service) requires the unit file to already exist; if absent, it
short-circuits with 'Gateway service disabled' before our systemctl
shim is invoked. Run 'openclaw gateway install' once per container
so the shim's restart path is reachable."
```

---

## Task 4: Integration test — build and verify end-to-end

**Files:** (no source edits; operational verification)

- [ ] **Step 1: Build the image**

Run:
```bash
docker compose build 2>&1 | tail -20
```
Expected: build completes without error, final line mentions the image tag.

- [ ] **Step 2: Start a fresh container (clean volume)**

Run:
```bash
docker compose down -v 2>&1 | tail -3
docker compose up -d 2>&1 | tail -3
until docker logs openclaw-desktop 2>&1 | grep -qE "Gateway : (running|start failed)"; do sleep 3; done
echo "ready"
```
Expected: final line prints `ready`.

- [ ] **Step 3: Verify PATH and shim are in place**

Run:
```bash
docker exec openclaw-desktop bash -c 'which systemctl; ls -la /usr/bin/systemctl /usr/bin/systemctl.real; echo PATH=$PATH'
```
Expected:
- `which systemctl` → `/usr/bin/systemctl`
- `ls` shows symlink `/usr/bin/systemctl -> /usr/local/bin/systemctl-shim` and the real binary at `/usr/bin/systemctl.real`
- `PATH` starts with `/var/openclaw-npm/bin:`

- [ ] **Step 4: Verify unit file auto-installed**

Run:
```bash
docker exec -u claw openclaw-desktop ls -la /home/claw/.config/systemd/user/openclaw-gateway.service
```
Expected: file exists (size > 0).

- [ ] **Step 5: Verify shim responds correctly in-container**

Run:
```bash
docker exec -u claw openclaw-desktop bash -lc '
    systemctl --user is-enabled openclaw-gateway.service
    systemctl --user show openclaw-gateway.service --no-page --property ActiveState,SubState,MainPID,ExecMainStatus,ExecMainCode
'
```
Expected:
```
enabled
ActiveState=active
SubState=running
MainPID=<some number>
ExecMainStatus=0
ExecMainCode=0
```

- [ ] **Step 6: Run an update and verify the gateway actually restarts with new code**

Run:
```bash
docker exec -u claw openclaw-desktop bash -lc '
GW_PID_BEFORE=$(pgrep -u $(id -u) -f "^openclaw-gateway$" | head -1)
echo "PID before: $GW_PID_BEFORE"
openclaw gateway probe 2>&1 | grep "Gateway:"
echo "=== openclaw update --yes ==="
openclaw update --yes 2>&1 | tail -10
sleep 5
GW_PID_AFTER=$(pgrep -u $(id -u) -f "^openclaw-gateway$" | head -1)
echo "PID after: $GW_PID_AFTER"
[ "$GW_PID_BEFORE" != "$GW_PID_AFTER" ] && echo "PASS: gateway restarted" || echo "FAIL: same PID"
sleep 2
openclaw gateway probe 2>&1 | grep "Gateway:"
openclaw update status 2>&1 | grep -E "Update\s" | head -2
'
```
Expected:
- `PID after` differs from `PID before`.
- The line `PASS: gateway restarted` appears.
- Final `update status` shows `up to date` (not `available`).

- [ ] **Step 7: Run a standalone `openclaw gateway restart` and verify it also works**

Run:
```bash
docker exec -u claw openclaw-desktop bash -lc '
GW_PID_BEFORE=$(pgrep -u $(id -u) -f "^openclaw-gateway$" | head -1)
openclaw gateway restart 2>&1 | tail -5
sleep 5
GW_PID_AFTER=$(pgrep -u $(id -u) -f "^openclaw-gateway$" | head -1)
[ "$GW_PID_BEFORE" != "$GW_PID_AFTER" ] && echo "PASS" || echo "FAIL"
'
```
Expected: prints `PASS`.

- [ ] **Step 8: Verify that no spurious kills hit unrelated processes**

Run:
```bash
docker exec -u claw openclaw-desktop bash -c '
    ps -ef | grep -E "Xtigervnc|xrdp|xfce4-session" | grep -v grep | wc -l
'
```
Expected: a number ≥ 2 (VNC + XFCE still running after all those restarts; nothing in the shim should have killed them).

- [ ] **Step 9: Tear down**

Run:
```bash
docker compose down
```
Expected: container removed cleanly.

- [ ] **Step 10: No commit** (this task is verification only)

If any step fails, stop and diagnose before proceeding to later tasks.

---

## Task 5: Update READMEs — remove "ignore this" advice

**Files:**
- Modify: `README.md`, `README.ko.md`, `README.ja.md`, `README.zh.md`

The current READMEs tell users that the gateway daemon install step "will fail — ignore this". After this change that advice is wrong; the unit file installs cleanly, and update/restart now complete successfully.

- [ ] **Step 1: Update `README.md`**

Locate this paragraph in `README.md`:

```markdown
Since Docker has no systemd, the Gateway daemon install step during onboarding will fail — **this is expected and can be safely ignored**. The entrypoint manages the Gateway process directly.
```

Replace it with:

```markdown
The container ships a `systemctl` shim that translates OpenClaw's systemd-user calls into direct process management, so `openclaw update` and `openclaw gateway restart` — and the equivalent dashboard flows — complete cleanly. The gateway unit file is auto-registered on first boot; no manual `openclaw gateway install` is needed.
```

Then locate the onboarding bullet list:

```markdown
4. **Gateway daemon** — will fail (no systemd) — ignore this
```

Replace it with:

```markdown
4. **Gateway daemon** — installs cleanly via the systemctl shim
```

Then locate the troubleshooting row (around line 280):

```markdown
| VNC↔RDP display mismatch | `openclaw-sync-display` helper auto-detects active session (VNC `:1` vs xRDP `:10+`), restarts gateway with correct DISPLAY; `.bashrc` hook catches transitions |
```

Immediately before or after that row, add:

```markdown
| `openclaw update` leaves dashboard showing "update available" | `systemctl` shim translates OpenClaw's systemd restart calls into direct process management, so update + restart complete atomically |
```

Finally locate this paragraph (around line 314):

```markdown
This is expected — Docker containers have no systemd. The entrypoint handles Gateway lifecycle instead. Ignore this message.
```

Replace it with:

```markdown
Earlier versions of this image surfaced a "systemd not available" message because Docker containers have no systemd. The current image ships a shim that handles these calls transparently; you should no longer see this message during onboarding. If you do, check that `/usr/bin/systemctl` is a symlink to `/usr/local/bin/systemctl-shim`.
```

- [ ] **Step 2: Apply the equivalent replacements to `README.ko.md`**

Find and replace the Korean equivalents. The Korean-language paragraphs to replace:

Old (around line 113):
```markdown
Docker에는 systemd가 없으므로, 온보딩 중 Gateway 데몬 설치 단계는 실패합니다 — **이는 정상이며 무시해도 됩니다**. 엔트리포인트가 Gateway 프로세스를 직접 관리합니다.
```
New:
```markdown
이 이미지에는 `systemctl` 셰비가 포함되어 있어 OpenClaw의 systemd-user 호출을 프로세스 관리로 변환합니다. 따라서 `openclaw update`, `openclaw gateway restart` 및 대시보드의 동일 기능이 모두 깔끔하게 완료됩니다. Gateway unit 파일은 첫 부팅 시 자동 등록되므로 수동으로 `openclaw gateway install`을 실행할 필요가 없습니다.
```

Old (around line 132):
```markdown
4. **Gateway 데몬** — 실패함 (systemd 없음) — 무시하세요
```
New:
```markdown
4. **Gateway 데몬** — systemctl 셰비를 통해 깔끔하게 설치됨
```

Old (around line 314):
```markdown
이는 정상입니다 — Docker 컨테이너에는 systemd가 없습니다. 엔트리포인트가 대신 Gateway 생명주기를 관리합니다. 이 메시지를 무시하세요.
```
New:
```markdown
이전 버전의 이미지에서는 Docker 컨테이너에 systemd가 없어서 "systemd not available" 메시지가 뜨곤 했습니다. 현재 이미지는 셰비로 이 호출을 투명하게 처리하므로 온보딩 중 이 메시지가 보이지 않아야 합니다. 만약 보인다면 `/usr/bin/systemctl`이 `/usr/local/bin/systemctl-shim`을 가리키는 심볼릭 링크인지 확인하세요.
```

Also add the new troubleshooting table row (Korean translation of the English row added in Step 1):
```markdown
| `openclaw update` 후 대시보드가 계속 "업데이트 가능"으로 표시 | `systemctl` 셰비가 OpenClaw의 systemd restart 호출을 직접 프로세스 관리로 변환 — 업데이트와 재시작이 원자적으로 완료 |
```

- [ ] **Step 3: Apply the equivalent replacements to `README.ja.md`**

Old (around line 113):
```markdown
Dockerにはsystemdがないため、オンボーディング中のGatewayデーモンインストールステップは失敗します — **これは想定通りであり、安全に無視できます**。エントリポイントがGatewayプロセスを直接管理します。
```
New:
```markdown
このイメージには OpenClaw の systemd-user 呼び出しをプロセス管理に変換する `systemctl` シムが含まれています。そのため `openclaw update` や `openclaw gateway restart`、およびダッシュボードの同等の操作がすべてクリーンに完了します。Gateway の unit ファイルは初回起動時に自動登録されるので、手動で `openclaw gateway install` を実行する必要はありません。
```

Old (around line 132):
```markdown
4. **Gatewayデーモン** — 失敗します（systemdなし）— 無視してください
```
New:
```markdown
4. **Gatewayデーモン** — systemctl シム経由でクリーンにインストールされます
```

Old (around line 314):
```markdown
これは想定通りです — Dockerコンテナにはsystemdがありません。エントリポイントが代わりにGatewayのライフサイクルを管理します。このメッセージは無視してください。
```
New:
```markdown
以前のバージョンのイメージでは Docker コンテナに systemd がないため "systemd not available" メッセージが表示されていました。現在のイメージはシムでこの呼び出しを透過的に処理するため、オンボーディング中にこのメッセージは表示されないはずです。もし表示された場合は、`/usr/bin/systemctl` が `/usr/local/bin/systemctl-shim` へのシンボリックリンクになっているか確認してください。
```

Troubleshooting table row:
```markdown
| `openclaw update` 後にダッシュボードが "アップデート可能" のまま表示される | `systemctl` シムが OpenClaw の systemd restart 呼び出しを直接プロセス管理に変換 — アップデートと再起動がアトミックに完了 |
```

- [ ] **Step 4: Apply the equivalent replacements to `README.zh.md`**

Old (around line 113):
```markdown
由于 Docker 没有 systemd，引导过程中的 Gateway 守护进程安装步骤会失败 — **这是正常的，可以安全忽略**。入口脚本直接管理 Gateway 进程。
```
New:
```markdown
本镜像内置 `systemctl` 垫片，可将 OpenClaw 的 systemd-user 调用转换为直接进程管理。因此 `openclaw update`、`openclaw gateway restart` 及仪表板中的等价操作都能干净完成。Gateway 的 unit 文件在首次启动时自动注册，无需手动运行 `openclaw gateway install`。
```

Old (around line 132):
```markdown
4. **Gateway 守护进程** — 会失败（无 systemd）— 忽略即可
```
New:
```markdown
4. **Gateway 守护进程** — 通过 systemctl 垫片干净安装
```

Old (around line 314):
```markdown
这是正常的 — Docker 容器没有 systemd。入口脚本会代替管理 Gateway 生命周期。请忽略此消息。
```
New:
```markdown
旧版本镜像因 Docker 容器缺少 systemd 会提示 "systemd not available"。当前镜像通过垫片透明处理该调用，引导过程中不应再看到此消息。如仍出现，请检查 `/usr/bin/systemctl` 是否是指向 `/usr/local/bin/systemctl-shim` 的符号链接。
```

Troubleshooting table row:
```markdown
| `openclaw update` 后仪表板持续显示"可用更新" | `systemctl` 垫片将 OpenClaw 的 systemd 重启调用转换为直接进程管理 — 更新与重启原子完成 |
```

- [ ] **Step 5: Commit**

```bash
git add README.md README.ko.md README.ja.md README.zh.md
git commit -m "docs: replace 'ignore systemd failure' advice with shim-based flow

The systemctl shim and auto-unit-install now make the update/restart
path work end-to-end. Update all four READMEs to describe the new
behavior, remove the stale 'this will fail — ignore this' warnings,
and add a troubleshooting row for the most common symptom (dashboard
stuck on 'update available')."
```

---

## Task 6: Close out TODO.md

**Files:**
- Modify: `TODO.md`

- [ ] **Step 1: Update the pending list**

Open `TODO.md`. It currently lists C5 (verify seccomp) and C4 (optional NoVNC TLS). Both remain pending. Add a historical note that the update-flow issue is now resolved:

Locate the top of the file:

```markdown
# TODO

Deferred items from the security review (see commits `803ffe7`, `3aafb70`, `7639aa1`).

## Pending
```

Replace it with:

```markdown
# TODO

Deferred items from the security review and the systemctl-shim work.

## Resolved

- **Update/restart flow** — `openclaw update` and dashboard "Restart Gateway" now complete end-to-end via the `systemctl` shim (see `docs/superpowers/specs/2026-04-19-systemctl-shim-design.md`).

## Pending
```

- [ ] **Step 2: Commit**

```bash
git add TODO.md
git commit -m "docs: note update-flow is resolved in TODO"
```

---

## Self-Review Notes

- **Spec coverage:** Each of the four components in the spec has at least one task (shim → Task 1; Dockerfile changes → Task 2; unit auto-install → Task 3; lsof is folded into Task 2 Step 2).
- **Placeholder scan:** No TBD/TODO/implement-later strings. Each task step contains either exact code or exact commands with expected output.
- **Type consistency:** The pkill/pgrep pattern is `^openclaw-gateway$` everywhere (shim + verification steps). The unit-file path is `/home/${USER}/.config/systemd/user/openclaw-gateway.service` in both the entrypoint change and Task 4 Step 4 verification.
- **Scope boundary:** This plan does NOT eliminate the baked `/usr/lib/node_modules/openclaw` — spec Open Question #1 defers that to a separate change. The PATH prepend is sufficient to let `/var/openclaw-npm/bin/openclaw` win where needed.
