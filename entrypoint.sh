#!/bin/bash
set -e

USER="${USER:-claw}"
PASSWORD="${PASSWORD:-claw1234}"
VNC_PORT="${VNC_PORT:-5901}"
NOVNC_PORT="${NOVNC_PORT:-6080}"
VNC_RESOLUTION="${VNC_RESOLUTION:-1920x1080}"
VNC_COL_DEPTH="${VNC_COL_DEPTH:-24}"
OPENCLAW_BROWSER_ENABLED="${OPENCLAW_BROWSER_ENABLED:-false}"

# ── Dynamic user creation ────────────────────────────────
# Creates the Linux user at runtime so that USER/PASSWORD
# from docker-compose environment (or .env) take effect.
if ! id "${USER}" &>/dev/null; then
    echo ">> Creating user '${USER}'..."
    useradd -m -s /bin/bash "${USER}"
    usermod -aG sudo "${USER}"
    echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"${USER}"
    chmod 0440 /etc/sudoers.d/"${USER}"

    # Initialize home directory from build-time templates
    if [ -d /opt/openclaw-defaults ]; then
        cp -a /opt/openclaw-defaults/. /home/${USER}/
        chown -R ${USER}:${USER} /home/${USER}
    fi
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

# Regenerate startwm.sh (XFCE4 session)
cp /opt/openclaw-configs/xrdp/startwm.sh /etc/xrdp/startwm.sh
chmod +x /etc/xrdp/startwm.sh

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

    # Docker bind:"lan" causes gateway URL to resolve to container LAN IP (172.x),
    # which triggers OpenClaw's ws:// security check (CWE-319, added in v2026.2.19).
    # This env var allows plaintext ws:// to RFC 1918 private IPs only.
    OPENCLAW_ENV="${OPENCLAW_DIR}/.env"
    touch "${OPENCLAW_ENV}"
    if ! grep -q "^OPENCLAW_ALLOW_INSECURE_PRIVATE_WS=" "${OPENCLAW_ENV}" 2>/dev/null; then
        echo "OPENCLAW_ALLOW_INSECURE_PRIVATE_WS=1" >> "${OPENCLAW_ENV}"
    fi

    # ── Auto-detect X11 DISPLAY and XAUTHORITY ─────────────────
    # Always register these so browser features work without manual setup.
    # OpenClaw gateway reads ~/.openclaw/.env to find the X11 display
    # when launching Chrome via CDP (browser profile "openclaw").
    DETECTED_DISPLAY="${DISPLAY:-:1}"
    if [ ! -S "/tmp/.X11-unix/X${DETECTED_DISPLAY#:}" ]; then
        # Configured DISPLAY socket not found — scan for any active one
        for sock in /tmp/.X11-unix/X*; do
            if [ -S "$sock" ]; then
                DETECTED_DISPLAY=":$(basename "$sock" | sed 's/^X//')"
                break
            fi
        done
    fi
    DETECTED_XAUTHORITY="/home/${USER}/.Xauthority"

    # Update or add DISPLAY
    if grep -q "^DISPLAY=" "${OPENCLAW_ENV}" 2>/dev/null; then
        sed -i "s|^DISPLAY=.*|DISPLAY=${DETECTED_DISPLAY}|" "${OPENCLAW_ENV}"
    else
        echo "DISPLAY=${DETECTED_DISPLAY}" >> "${OPENCLAW_ENV}"
    fi
    # Update or add XAUTHORITY
    if grep -q "^XAUTHORITY=" "${OPENCLAW_ENV}" 2>/dev/null; then
        sed -i "s|^XAUTHORITY=.*|XAUTHORITY=${DETECTED_XAUTHORITY}|" "${OPENCLAW_ENV}"
    else
        echo "XAUTHORITY=${DETECTED_XAUTHORITY}" >> "${OPENCLAW_ENV}"
    fi
    echo "   DISPLAY=${DETECTED_DISPLAY}"
    echo "   XAUTHORITY=${DETECTED_XAUTHORITY}"

    chown ${USER}:${USER} "${OPENCLAW_ENV}"
    chmod 600 "${OPENCLAW_ENV}"

    echo ">> Starting OpenClaw Gateway..."

    GATEWAY_LOG="${OPENCLAW_DIR}/gateway.log"
    su - "${USER}" -c "nohup openclaw gateway run >> ${GATEWAY_LOG} 2>&1 &"

    sleep 3

    if su - "${USER}" -c "pgrep -f 'openclaw gateway' > /dev/null 2>&1"; then
        echo "Gateway : running ✓"
        echo "Dashboard: http://localhost:18789/"
        echo ""
        echo "  Set AI model via Dashboard if not configured"

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
