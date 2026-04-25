#!/bin/bash
set -e

USER="${USER:-claw}"
PASSWORD="${PASSWORD:-claw1234}"
VNC_PORT="${VNC_PORT:-5901}"
NOVNC_PORT="${NOVNC_PORT:-6080}"
VNC_RESOLUTION="${VNC_RESOLUTION:-1920x1080}"
VNC_COL_DEPTH="${VNC_COL_DEPTH:-24}"
OPENCLAW_BROWSER_ENABLED="${OPENCLAW_BROWSER_ENABLED:-false}"
OPENCLAW_DISPLAY_TARGET="${OPENCLAW_DISPLAY_TARGET:-auto}"

# ── Input validation ────────────────────────────────────
# USER and PASSWORD are interpolated into shell commands (su -c, sudoers,
# chpasswd). Reject values containing characters that would break parsing
# or enable command injection.
if ! [[ "$USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
    echo "FATAL: invalid USER '$USER' (must match ^[a-z_][a-z0-9_-]{0,31}$)"; exit 1
fi
case "$PASSWORD" in
    *[$'\n\r:']*) echo "FATAL: PASSWORD contains forbidden characters (newline, CR, or colon)"; exit 1 ;;
esac

# ── Dynamic user creation ────────────────────────────────
# Creates the Linux user at runtime so that USER/PASSWORD
# from docker-compose environment (or .env) take effect.
if ! id "${USER}" &>/dev/null; then
    echo ">> Creating user '${USER}'..."
    useradd -m -s /bin/bash "${USER}"
    usermod -aG sudo "${USER}"
    # Add to the openclaw group (created at build time) so the user can
    # write into /usr/lib/node_modules/openclaw/dist/extensions/*/node_modules
    # for plugin runtime-dep installs without resorting to world-writable
    # paths (which OpenClaw rejects as a security hardening measure).
    if getent group openclaw >/dev/null 2>&1; then
        usermod -aG openclaw "${USER}"
    fi
    SUDOERS_TMP=$(mktemp)
    echo "${USER} ALL=(ALL) NOPASSWD:ALL" > "${SUDOERS_TMP}"
    if visudo -c -f "${SUDOERS_TMP}" >/dev/null; then
        mv "${SUDOERS_TMP}" /etc/sudoers.d/"${USER}"
        chmod 0440 /etc/sudoers.d/"${USER}"
    else
        rm -f "${SUDOERS_TMP}"
        echo "FATAL: generated sudoers entry failed visudo check"; exit 1
    fi

    # Seed /etc/skel files (.bashrc, .profile, .bash_logout). When /home/${USER}
    # is mounted from an empty named volume, the directory pre-exists so
    # `useradd -m` skips skel copy. Without this, .bashrc never gets created
    # via skel and any later root-side append produces a root-owned file the
    # user cannot rewrite (breaks `openclaw update` shell-completion install).
    if [ -d /etc/skel ]; then
        cp -an /etc/skel/. /home/${USER}/ 2>/dev/null || true
    fi

    # Initialize home directory from build-time templates
    if [ -d /opt/openclaw-defaults ]; then
        cp -a /opt/openclaw-defaults/. /home/${USER}/
    fi
    chown -R ${USER}:${USER} /home/${USER}
fi

# Always sync password (handles password-only changes without rebuild)
echo "${USER}:${PASSWORD}" | chpasswd

echo "============================================"
echo " OpenClaw Docker Environment"
echo "============================================"
echo " User     : ${USER}"
echo " VNC      : :${VNC_PORT}"
echo " NoVNC    : :${NOVNC_PORT}  (web browser)"
echo " RDP      : :3389"
echo " Password : ${PASSWORD}"
echo "============================================"

# ── VNC password file generation ────────────────────────────────
echo ">> Setting VNC password..."
PASSWD_FILE="/home/${USER}/.vnc/passwd"
mkdir -p "/home/${USER}/.vnc"
echo "${PASSWORD}" | vncpasswd -f > "${PASSWD_FILE}"
chmod 600 "${PASSWD_FILE}"
chown "${USER}:${USER}" "${PASSWD_FILE}"

# ── Start D-Bus ────────────────────────────────────────────
mkdir -p /run/dbus
if [ ! -S /run/dbus/system_bus_socket ]; then
    rm -f /var/run/dbus/pid
    dbus-daemon --system --fork 2>/dev/null || true
fi

# ── Clean up existing VNC session ────────────────────────────────────
su - "${USER}" -c "vncserver -kill :1" 2>/dev/null || true
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1

# ── Set desktop wallpaper (MUST run before VNC/XFCE starts) ────
echo ">> Setting desktop wallpaper..."
WALLPAPER="/usr/share/backgrounds/dockerized_openclaw.png"
XFCE_CONF_DIR="/home/${USER}/.config/xfce4/xfconf/xfce-perchannel-xml"
mkdir -p "${XFCE_CONF_DIR}"

# Copy system XFCE4 defaults first (panel layout, session config, etc.)
# Without this, XFCE skips first-run panel initialization when it sees
# a partially populated xfconf directory (our wallpaper XML below).
if [ ! -f "${XFCE_CONF_DIR}/xfce4-panel.xml" ]; then
    cp -rn /etc/xdg/xfce4/. "/home/${USER}/.config/xfce4/" 2>/dev/null || true
fi

# Generate workspace block helper (4 workspaces)
ws_block() {
    local img="$1"
    for i in 0 1 2 3; do
        cat << WSEOF
        <property name="workspace${i}" type="empty">
          <property name="last-image" type="string" value="${img}"/>
          <property name="image-style" type="int" value="5"/>
          <property name="color-style" type="int" value="0"/>
        </property>
WSEOF
    done
}

# Cover all monitor names: VNC-0, rdp0, screen (fallback)
cat > "${XFCE_CONF_DIR}/xfce4-desktop.xml" << WALLEOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitorVNC-0" type="empty">
$(ws_block "${WALLPAPER}")
      </property>
      <property name="monitorrdp0" type="empty">
$(ws_block "${WALLPAPER}")
      </property>
      <property name="monitorscreen" type="empty">
$(ws_block "${WALLPAPER}")
      </property>
    </property>
  </property>
</channel>
WALLEOF
chown -R ${USER}:${USER} "/home/${USER}/.config/xfce4"

# ── Regenerate xstartup (overwrite cached version from volume) ─────
cp /opt/openclaw-configs/vnc/xstartup /home/${USER}/.vnc/xstartup
chmod +x /home/${USER}/.vnc/xstartup
chown ${USER}:${USER} /home/${USER}/.vnc/xstartup

# ── Start VNC server ─────────────────────────────────────────
echo ">> Starting VNC server (${VNC_RESOLUTION})..."
su - "${USER}" -c "vncserver :1 \
    -geometry ${VNC_RESOLUTION} \
    -depth ${VNC_COL_DEPTH} \
    -localhost no \
    -SecurityTypes VncAuth \
    -passwd /home/${USER}/.vnc/passwd"

sleep 2

# ── Start NoVNC (websockify) ───────────────────────────────
echo ">> Starting NoVNC (port ${NOVNC_PORT})..."

NOVNC_PATH="/usr/share/novnc"
[ ! -d "${NOVNC_PATH}" ] && NOVNC_PATH="/usr/share/novnc/utils/../"

websockify --web="${NOVNC_PATH}" "${NOVNC_PORT}" localhost:"${VNC_PORT}" &
WEBSOCKIFY_PID=$!

sleep 1

# ── Start xRDP ─────────────────────────────────────────────
echo ">> Starting xRDP server (port 3389)..."

# Regenerate startwm.sh + reconnectwm.sh (xRDP session hooks)
cp /opt/openclaw-configs/xrdp/startwm.sh /etc/xrdp/startwm.sh
cp /opt/openclaw-configs/xrdp/reconnectwm.sh /etc/xrdp/reconnectwm.sh
chmod +x /etc/xrdp/startwm.sh /etc/xrdp/reconnectwm.sh

if [ ! -f /etc/xrdp/rsakeys.ini ]; then
    xrdp-keygen xrdp /etc/xrdp/rsakeys.ini 2>/dev/null || true
fi

# Fix TLS cert permissions (prevent Permission denied)
if [ -f /etc/xrdp/key.pem ]; then
    chmod 640 /etc/xrdp/key.pem
    chgrp ssl-cert /etc/xrdp/key.pem 2>/dev/null || chmod 644 /etc/xrdp/key.pem
fi

/etc/init.d/xrdp start 2>/dev/null || xrdp || true

sleep 1

# ── Chrome default browser (XFCE + XDG) ────────────────
# 1) XFCE exo-helper config (used by "Web Browser" button)
mkdir -p /home/${USER}/.config/xfce4
HELPERS_RC="/home/${USER}/.config/xfce4/helpers.rc"
if [ -f "${HELPERS_RC}" ]; then
    if grep -q "^WebBrowser=" "${HELPERS_RC}"; then
        sed -i 's|^WebBrowser=.*|WebBrowser=custom-GoogleChrome|' "${HELPERS_RC}"
    else
        echo "WebBrowser=custom-GoogleChrome" >> "${HELPERS_RC}"
    fi
else
    echo "WebBrowser=custom-GoogleChrome" > "${HELPERS_RC}"
fi

# 2) XFCE custom helper (wrapper handles --no-sandbox)
mkdir -p /home/${USER}/.local/share/xfce4/helpers
cp /opt/openclaw-configs/xfce4/custom-GoogleChrome.desktop \
    /home/${USER}/.local/share/xfce4/helpers/custom-GoogleChrome.desktop

# 3) XDG mime + mimeapps.list
mkdir -p /home/${USER}/.config
cp /opt/openclaw-configs/xfce4/mimeapps.list /home/${USER}/.config/mimeapps.list

# 4) Clean Chrome crash/lock files (prevent stale state)
rm -f /home/${USER}/.config/google-chrome/SingletonLock 2>/dev/null || true
rm -f /home/${USER}/.config/google-chrome/SingletonSocket 2>/dev/null || true
rm -f /home/${USER}/.config/google-chrome/SingletonCookie 2>/dev/null || true

# Fix ownership
chown -R ${USER}:${USER} /home/${USER}/.config
chown -R ${USER}:${USER} /home/${USER}/.local

# ── Auto display-sync on terminal open (.bashrc hook) ────────────────
# VNC sessions persist across reconnects (xstartup doesn't re-run),
# so we add a lightweight check to .bashrc: if the current terminal's
# DISPLAY differs from the gateway's, run openclaw-sync-display.
# This handles both VNC→RDP and RDP→VNC transitions.
BASHRC="/home/${USER}/.bashrc"
SYNC_MARKER="# openclaw-display-sync"
if ! grep -q "${SYNC_MARKER}" "${BASHRC}" 2>/dev/null; then
    # Touch as user (not root) so a missing .bashrc gets the right owner.
    [ -f "${BASHRC}" ] || su - "${USER}" -c "touch ${BASHRC}" 2>/dev/null
    cat >> "${BASHRC}" << 'BASHRC_EOF'

# openclaw-display-sync
# Auto-detect display change when opening a new terminal (VNC↔RDP)
if command -v openclaw-sync-display >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
    _oc_gw_pid=$(pgrep -u "$(id -u)" -f 'openclaw-gateway' 2>/dev/null | head -1)
    if [ -n "${_oc_gw_pid}" ]; then
        _oc_gw_disp=$(tr '\0' '\n' < "/proc/${_oc_gw_pid}/environ" 2>/dev/null | grep '^DISPLAY=' | cut -d= -f2)
        if [ -n "${_oc_gw_disp}" ] && [ "${_oc_gw_disp}" != "${DISPLAY}" ]; then
            openclaw-sync-display "$(whoami)" 2>/dev/null || true
        fi
    fi
    unset _oc_gw_pid _oc_gw_disp
fi
BASHRC_EOF
    # Append above ran as root — restore ownership so the user can later
    # modify their own .bashrc (e.g., shell-completion install via openclaw update).
    chown "${USER}:${USER}" "${BASHRC}" 2>/dev/null || true
fi

# ── npm global prefix (user-writable, OUTSIDE home) ──────────────────
# Lives at /var/openclaw-npm so the home volume doesn't persist installed
# packages — that would shadow the image-baked openclaw on version upgrade.
# Trade-off: clawhub-installed skills are reset on container recreate.
NPMRC="/home/${USER}/.npmrc"
NPM_GLOBAL_DIR="/var/openclaw-npm"
echo "prefix=${NPM_GLOBAL_DIR}" > "${NPMRC}"
chown "${USER}:${USER}" "${NPMRC}"

mkdir -p "${NPM_GLOBAL_DIR}"
chown -R "${USER}:${USER}" "${NPM_GLOBAL_DIR}"

# Migration: drop legacy ~/.npm-global PATH block written by older images
if grep -q '^# npm-global-prefix$' "${BASHRC}" 2>/dev/null; then
    sed -i '/^# npm-global-prefix$/,+1d' "${BASHRC}"
fi

# Add /var/openclaw-npm/bin to PATH for interactive shells
NPM_MARKER="# openclaw-npm-prefix"
if ! grep -q "${NPM_MARKER}" "${BASHRC}" 2>/dev/null; then
    cat >> "${BASHRC}" << 'BASHRC_NPM_EOF'

# openclaw-npm-prefix
export PATH="/var/openclaw-npm/bin:${PATH}"
BASHRC_NPM_EOF
fi

# ── Desktop shortcuts (regenerate if missing from volume) ────────────
DESKTOP_DIR="/home/${USER}/Desktop"
mkdir -p "${DESKTOP_DIR}"

# Clean up old icon names
rm -f "${DESKTOP_DIR}/openclaw-model-setup.desktop" 2>/dev/null || true

for shortcut in openclaw-setup.desktop openclaw-dashboard.desktop openclaw-terminal.desktop; do
    if [ ! -f "${DESKTOP_DIR}/${shortcut}" ]; then
        cp /opt/openclaw-configs/desktop/${shortcut} "${DESKTOP_DIR}/${shortcut}"
    fi
done

# Icon permissions + XFCE trust settings
for f in "${DESKTOP_DIR}"/*.desktop; do
    chmod +x "$f"
    # Prevent XFCE "untrusted app" warning
    su - "${USER}" -c "dbus-launch gio set '$f' metadata::trusted true" 2>/dev/null || true
done
chown -R ${USER}:${USER} "${DESKTOP_DIR}"

# ── OpenClaw Gateway auto-start (replaces systemd) ─────────────
echo ""
echo "── OpenClaw Status ──"
if command -v openclaw &>/dev/null; then
    CLAW_VER=$(openclaw --version 2>/dev/null || echo "installed")
    echo "OpenClaw: ${CLAW_VER}"
    echo "Node.js : $(node --version 2>/dev/null)"

    # Ensure default config exists (restore if missing from volume)
    OPENCLAW_DIR="/home/${USER}/.openclaw"
    OPENCLAW_CFG="${OPENCLAW_DIR}/openclaw.json"
    if [ ! -f "${OPENCLAW_CFG}" ]; then
        echo ">> Restoring default config..."
        mkdir -p "${OPENCLAW_DIR}/workspace"
        cp /opt/openclaw-configs/openclaw.json "${OPENCLAW_CFG}"
        chown -R ${USER}:${USER} "${OPENCLAW_DIR}"
        chmod 700 "${OPENCLAW_DIR}"
        chmod 600 "${OPENCLAW_CFG}"
    fi

    echo "Config  : ${OPENCLAW_CFG}"

    # ── Policy-based display targeting ─────────────────────────
    # Replaces naive one-time detection. The helper script handles:
    # - DISPLAY / XAUTHORITY resolution (auto / vnc / rdp / override)
    # - OPENCLAW_ALLOW_INSECURE_PRIVATE_WS flag
    # - Browser/gateway restart on display change
    OPENCLAW_ENV="${OPENCLAW_DIR}/.env"
    touch "${OPENCLAW_ENV}"

    # Bootstrap display targeting (helper creates/updates .env)
    if ! openclaw-sync-display "${USER}" "${OPENCLAW_DISPLAY_TARGET}"; then
        # Fallback: write essential values directly so gateway can start
        echo ">> WARN: display sync helper failed — using fallback DISPLAY=:1"
        grep -q "^DISPLAY=" "${OPENCLAW_ENV}" 2>/dev/null \
            && sed -i "s|^DISPLAY=.*|DISPLAY=:1|" "${OPENCLAW_ENV}" \
            || echo "DISPLAY=:1" >> "${OPENCLAW_ENV}"
        grep -q "^XAUTHORITY=" "${OPENCLAW_ENV}" 2>/dev/null \
            && sed -i "s|^XAUTHORITY=.*|XAUTHORITY=/home/${USER}/.Xauthority|" "${OPENCLAW_ENV}" \
            || echo "XAUTHORITY=/home/${USER}/.Xauthority" >> "${OPENCLAW_ENV}"
        grep -q "^OPENCLAW_ALLOW_INSECURE_PRIVATE_WS=" "${OPENCLAW_ENV}" 2>/dev/null \
            || echo "OPENCLAW_ALLOW_INSECURE_PRIVATE_WS=1" >> "${OPENCLAW_ENV}"
    fi
    chown ${USER}:${USER} "${OPENCLAW_ENV}"
    chmod 600 "${OPENCLAW_ENV}"

    echo "   DISPLAY=$(grep '^DISPLAY=' "${OPENCLAW_ENV}" 2>/dev/null | cut -d= -f2)"
    echo "   XAUTHORITY=$(grep '^XAUTHORITY=' "${OPENCLAW_ENV}" 2>/dev/null | cut -d= -f2)"

    echo ">> Starting OpenClaw Gateway..."

    GATEWAY_LOG="${OPENCLAW_DIR}/gateway.log"
    BOOT_DISPLAY=$(grep '^DISPLAY=' "${OPENCLAW_ENV}" 2>/dev/null | cut -d= -f2)
    BOOT_DISPLAY="${BOOT_DISPLAY:-:1}"
    BOOT_XAUTHORITY=$(grep '^XAUTHORITY=' "${OPENCLAW_ENV}" 2>/dev/null | cut -d= -f2)
    BOOT_XAUTHORITY="${BOOT_XAUTHORITY:-/home/${USER}/.Xauthority}"
    su - "${USER}" -c "DISPLAY='${BOOT_DISPLAY}' XAUTHORITY='${BOOT_XAUTHORITY}' nohup openclaw gateway run >> ${GATEWAY_LOG} 2>&1 &"

    # Poll for the gateway process. Pattern is 'openclaw-gateway' (hyphen),
    # the actual binary name — using 'openclaw gateway' (space) would
    # spuriously match the su -c "...openclaw gateway run..." command line
    # and report success even when the gateway failed to start.
    GATEWAY_READY=false
    for _ in $(seq 1 15); do
        if pgrep -u "${USER}" -f 'openclaw-gateway' >/dev/null 2>&1; then
            GATEWAY_READY=true
            break
        fi
        sleep 1
    done

    if [ "${GATEWAY_READY}" = "true" ]; then
        # Record the worker PID so the systemctl shim can target it on restart
        # without pkill-matching transient `openclaw-gateway` workers spawned
        # by `openclaw gateway install --force` (which would otherwise die with
        # SIGTERM and surface as "updated install refresh failed").
        GATEWAY_PID=$(pgrep -u "${USER}" -f 'openclaw-gateway' 2>/dev/null | head -1)
        if [ -n "${GATEWAY_PID}" ]; then
            su - "${USER}" -c "mkdir -p ~/.openclaw && echo '${GATEWAY_PID}' > ~/.openclaw/gateway.pid" 2>/dev/null || true
        fi

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

        # ── OpenClaw Browser configuration ────────────────────
        if [ "${OPENCLAW_BROWSER_ENABLED}" = "true" ]; then
            echo ">> Configuring OpenClaw browser (CDP Chrome)..."
            su - "${USER}" -c "openclaw config set browser.enabled true --json" 2>/dev/null || true
            su - "${USER}" -c "openclaw config set browser.noSandbox true --json" 2>/dev/null || true
            su - "${USER}" -c "openclaw config set browser.defaultProfile openclaw" 2>/dev/null || true
            echo "Browser : enabled (profile: openclaw, noSandbox: true)"
        else
            echo "Browser : disabled (set OPENCLAW_BROWSER_ENABLED=true in .env to enable)"
        fi
    else
        echo "Gateway : start failed (log: ${GATEWAY_LOG})"
        echo "  Manual: nohup openclaw gateway run >> ~/.openclaw/gateway.log 2>&1 & disown"
    fi
else
    echo "OpenClaw not installed (npm install -g openclaw@latest)"
fi
echo ""

echo "============================================"
echo " Access:"
echo "   Web browser -> http://localhost:${NOVNC_PORT}/vnc.html"
echo "   RDP client  -> localhost:3389"
echo "   Default browser: Google Chrome"
echo "   OpenClaw UI -> http://localhost:18789/"
echo ""
echo " AI Model setup:"
echo "   Via Dashboard or terminal:"
echo "   openclaw config set agents.defaults.model.primary anthropic/claude-sonnet-4-6"
echo "============================================"

# ── Keep process alive ─────────────────────────────────────────
wait ${WEBSOCKIFY_PID}
