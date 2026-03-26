#!/bin/bash
set -e

USER="${USER:-claw}"
PASSWORD="${PASSWORD:-claw1234}"
VNC_PORT="${VNC_PORT:-5901}"
NOVNC_PORT="${NOVNC_PORT:-6080}"
VNC_RESOLUTION="${VNC_RESOLUTION:-1920x1080}"
VNC_COL_DEPTH="${VNC_COL_DEPTH:-24}"

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

VNC_PASSWD_OK=false

# Method 1: vncpasswd binary (most reliable)
for cmd in vncpasswd tigervncpasswd /usr/bin/vncpasswd /usr/bin/tigervncpasswd; do
    if [ -x "$(command -v $cmd 2>/dev/null || echo $cmd)" ] 2>/dev/null; then
        echo "   Method 1: using $cmd"
        echo "${PASSWORD}" | "$cmd" -f > "${PASSWD_FILE}" 2>/dev/null && VNC_PASSWD_OK=true && break
    fi
done

# Method 2: openssl + legacy provider (DES-ECB on OpenSSL 3.x)
if [ "$VNC_PASSWD_OK" = false ]; then
    echo "   Method 2: trying openssl (legacy provider)..."
    python3 << 'PYEOF' && VNC_PASSWD_OK=true
import subprocess, os, pwd

password = os.environ.get('PASSWORD', 'claw1234')[:8].ljust(8, '\x00')
key_bytes = bytes([int('{:08b}'.format(ord(c))[::-1], 2) for c in password])
key_hex = key_bytes.hex()

result = subprocess.run(
    ['openssl', 'enc', '-des-ecb', '-nopad', '-nosalt', '-K', key_hex,
     '-provider', 'legacy', '-provider', 'default'],
    input=b'\x00' * 8, capture_output=True
)
if result.returncode != 0:
    raise SystemExit(1)

user = os.environ.get('USER', 'claw')
pf = f'/home/{user}/.vnc/passwd'
with open(pf, 'wb') as f:
    f.write(result.stdout[:8])
os.chmod(pf, 0o600)
u = pwd.getpwnam(user)
os.chown(pf, u.pw_uid, u.pw_gid)
print('   openssl legacy -> OK')
PYEOF
fi

# Method 3: pure Python DES (no external deps)
if [ "$VNC_PASSWD_OK" = false ]; then
    echo "   Method 3: pure Python DES..."
    python3 << 'PYEOF'
import os, pwd, struct

# ── Minimal DES implementation for VNC password ──
# Initial/Final permutation tables, S-boxes, etc.
IP = [58,50,42,34,26,18,10,2,60,52,44,36,28,20,12,4,
      62,54,46,38,30,22,14,6,64,56,48,40,32,24,16,8,
      57,49,41,33,25,17,9,1,59,51,43,35,27,19,11,3,
      61,53,45,37,29,21,13,5,63,55,47,39,31,23,15,7]
FP = [40,8,48,16,56,24,64,32,39,7,47,15,55,23,63,31,
      38,6,46,14,54,22,62,30,37,5,45,13,53,21,61,29,
      36,4,44,12,52,20,60,28,35,3,43,11,51,19,59,27,
      34,2,42,10,50,18,58,26,33,1,41,9,49,17,57,25]
E = [32,1,2,3,4,5,4,5,6,7,8,9,8,9,10,11,12,13,12,13,14,15,16,17,
     16,17,18,19,20,21,20,21,22,23,24,25,24,25,26,27,28,29,28,29,30,31,32,1]
P = [16,7,20,21,29,12,28,17,1,15,23,26,5,18,31,10,
     2,8,24,14,32,27,3,9,19,13,30,6,22,11,4,25]
S = [
 [[14,4,13,1,2,15,11,8,3,10,6,12,5,9,0,7],[0,15,7,4,14,2,13,1,10,6,12,11,9,5,3,8],[4,1,14,8,13,6,2,11,15,12,9,7,3,10,5,0],[15,12,8,2,4,9,1,7,5,11,3,14,10,0,6,13]],
 [[15,1,8,14,6,11,3,4,9,7,2,13,12,0,5,10],[3,13,4,7,15,2,8,14,12,0,1,10,6,9,11,5],[0,14,7,11,10,4,13,1,5,8,12,6,9,3,2,15],[13,8,10,1,3,15,4,2,11,6,7,12,0,5,14,9]],
 [[10,0,9,14,6,3,15,5,1,13,12,7,11,4,2,8],[13,7,0,9,3,4,6,10,2,8,5,14,12,11,15,1],[13,6,4,9,8,15,3,0,11,1,2,12,5,10,14,7],[1,10,13,0,6,9,8,7,4,15,14,3,11,5,2,12]],
 [[7,13,14,3,0,6,9,10,1,2,8,5,11,12,4,15],[13,8,11,5,6,15,0,3,4,7,2,12,1,10,14,9],[10,6,9,0,12,11,7,13,15,1,3,14,5,2,8,4],[3,15,0,6,10,1,13,8,9,4,5,11,12,7,2,14]],
 [[2,12,4,1,7,10,11,6,8,5,3,15,13,0,14,9],[14,11,2,12,4,7,13,1,5,0,15,10,3,9,8,6],[4,2,1,11,10,13,7,8,15,9,12,5,6,3,0,14],[11,8,12,7,1,14,2,13,6,15,0,9,10,4,5,3]],
 [[12,1,10,15,9,2,6,8,0,13,3,4,14,7,5,11],[10,15,4,2,7,12,9,5,6,1,13,14,0,11,3,8],[9,14,15,5,2,8,12,3,7,0,4,10,1,13,11,6],[4,3,2,12,9,5,15,10,11,14,1,7,6,0,8,13]],
 [[4,11,2,14,15,0,8,13,3,12,9,7,5,10,6,1],[13,0,11,7,4,9,1,10,14,3,5,12,2,15,8,6],[1,4,11,13,12,3,7,14,10,15,6,8,0,5,9,2],[6,11,13,8,1,4,10,7,9,5,0,15,14,2,3,12]],
 [[13,2,8,4,6,15,11,1,10,9,3,14,5,0,12,7],[1,15,13,8,10,3,7,4,12,5,6,2,0,14,9,11],[7,11,4,1,9,12,14,2,0,6,10,13,15,3,5,8],[2,1,14,7,4,10,8,13,15,12,9,0,3,5,6,11]]
]
PC1 = [57,49,41,33,25,17,9,1,58,50,42,34,26,18,10,2,59,51,43,35,27,19,11,3,60,52,44,36,
       63,55,47,39,31,23,15,7,62,54,46,38,30,22,14,6,61,53,45,37,29,21,13,5,28,20,12,4]
PC2 = [14,17,11,24,1,5,3,28,15,6,21,10,23,19,12,4,26,8,16,7,27,20,13,2,41,52,31,37,47,55,30,40,51,45,33,48,44,49,39,56,34,53,46,42,50,36,29,32]
SHIFTS = [1,1,2,2,2,2,2,2,1,2,2,2,2,2,2,1]

def bits(v, n):
    return [(v >> (n-1-i)) & 1 for i in range(n)]

def frombits(b):
    v = 0
    for bit in b:
        v = (v << 1) | bit
    return v

def permute(block, table):
    return [block[t-1] for t in table]

def des_encrypt_block(block_bytes, key_bytes):
    block_bits = []
    for b in block_bytes:
        block_bits += bits(b, 8)
    key_bits = []
    for b in key_bytes:
        key_bits += bits(b, 8)

    key56 = permute(key_bits, PC1)
    C, D = key56[:28], key56[28:]
    subkeys = []
    for s in SHIFTS:
        C = C[s:] + C[:s]
        D = D[s:] + D[:s]
        subkeys.append(permute(C + D, PC2))

    block_bits = permute(block_bits, IP)
    L, R = block_bits[:32], block_bits[32:]

    for i in range(16):
        eR = permute(R, E)
        x = [eR[j] ^ subkeys[i][j] for j in range(48)]
        sout = []
        for si in range(8):
            chunk = x[si*6:(si+1)*6]
            row = (chunk[0] << 1) | chunk[5]
            col = (chunk[1] << 3) | (chunk[2] << 2) | (chunk[3] << 1) | chunk[4]
            sout += bits(S[si][row][col], 4)
        f = permute(sout, P)
        newR = [L[j] ^ f[j] for j in range(32)]
        L, R = R, newR

    result_bits = permute(R + L, FP)
    result = bytes([frombits(result_bits[i*8:(i+1)*8]) for i in range(8)])
    return result

password = os.environ.get('PASSWORD', 'claw1234')[:8].ljust(8, '\x00')
key = bytes([int('{:08b}'.format(ord(c))[::-1], 2) for c in password])
encrypted = des_encrypt_block(b'\x00' * 8, key)

user = os.environ.get('USER', 'claw')
pf = f'/home/{user}/.vnc/passwd'
with open(pf, 'wb') as f:
    f.write(encrypted)
os.chmod(pf, 0o600)
u = pwd.getpwnam(user)
os.chown(pf, u.pw_uid, u.pw_gid)
print('   pure Python DES -> OK')
PYEOF
    VNC_PASSWD_OK=true
fi

if [ "$VNC_PASSWD_OK" = false ]; then
    echo "ERROR: VNC password generation failed"
    exit 1
fi
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
chown -R ${USER}:${USER} "${XFCE_CONF_DIR}"

# ── Regenerate xstartup (overwrite cached version from volume) ─────
cat > /home/${USER}/.vnc/xstartup << 'XSTARTUP'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec dbus-launch --exit-with-session startxfce4
XSTARTUP
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
cat > /etc/xrdp/startwm.sh << 'STARTWM'
#!/bin/bash
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR
if [ -r /etc/profile ]; then
    . /etc/profile
fi
exec dbus-launch --exit-with-session startxfce4
STARTWM
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
cat > /home/${USER}/.local/share/xfce4/helpers/custom-GoogleChrome.desktop << 'EOF'
[Desktop Entry]
NoDisplay=true
Version=1.0
Encoding=UTF-8
Type=X-XFCE-Helper
X-XFCE-Binaries=google-chrome-stable
X-XFCE-Category=WebBrowser
X-XFCE-Commands=/usr/bin/google-chrome-stable
X-XFCE-CommandsWithParameter=/usr/bin/google-chrome-stable "%s"
Name=Google Chrome
Icon=google-chrome
EOF

# 3) XDG mime + mimeapps.list
mkdir -p /home/${USER}/.config
cat > /home/${USER}/.config/mimeapps.list << 'EOF'
[Default Applications]
text/html=google-chrome.desktop
x-scheme-handler/http=google-chrome.desktop
x-scheme-handler/https=google-chrome.desktop
x-scheme-handler/about=google-chrome.desktop
x-scheme-handler/unknown=google-chrome.desktop
application/xhtml+xml=google-chrome.desktop
EOF

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

if [ ! -f "${DESKTOP_DIR}/openclaw-setup.desktop" ]; then
    cat > "${DESKTOP_DIR}/openclaw-setup.desktop" << 'DESKEOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=OpenClaw Setup
Comment=OpenClaw onboarding (AI model, channels, skills)
Exec=xfce4-terminal -e "openclaw-setup.sh"
Icon=preferences-system
Terminal=false
Categories=Utility;
DESKEOF
fi

if [ ! -f "${DESKTOP_DIR}/openclaw-dashboard.desktop" ]; then
    cat > "${DESKTOP_DIR}/openclaw-dashboard.desktop" << 'DESKEOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=OpenClaw Dashboard
Comment=OpenClaw Dashboard (web browser)
Exec=openclaw dashboard
Icon=web-browser
Terminal=false
Categories=Network;
DESKEOF
fi

if [ ! -f "${DESKTOP_DIR}/openclaw-terminal.desktop" ]; then
    cat > "${DESKTOP_DIR}/openclaw-terminal.desktop" << 'DESKEOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=OpenClaw Terminal
Comment=OpenClaw CLI terminal
Exec=xfce4-terminal -e "bash -c 'openclaw; exec bash'"
Icon=utilities-terminal
Terminal=false
Categories=Utility;
DESKEOF
fi

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
        echo ">> Generating default config..."
        mkdir -p "${OPENCLAW_DIR}/workspace"
        cat > "${OPENCLAW_CFG}" << 'CLAWCFG'
{
  // OpenClaw Docker default config
  // Set your AI model via Dashboard (http://localhost:18789/)
  gateway: {
    mode: "local",
    port: 18789,
    bind: "lan",
    controlUi: {
      allowedOrigins: ["*"],
    },
  },
  agents: {
    defaults: {
      workspace: "~/.openclaw/workspace",
    },
  },
  env: {
    vars: {
      TZ: "Asia/Seoul",
    },
  },
}
CLAWCFG
        chown -R ${USER}:${USER} "${OPENCLAW_DIR}"
        chmod 700 "${OPENCLAW_DIR}"
        chmod 600 "${OPENCLAW_CFG}"
    fi

    echo "Config  : ${OPENCLAW_CFG}"
    echo ">> Starting OpenClaw Gateway..."

    GATEWAY_LOG="${OPENCLAW_DIR}/gateway.log"
    su - "${USER}" -c "nohup openclaw gateway run >> ${GATEWAY_LOG} 2>&1 &"

    sleep 3

    if su - "${USER}" -c "pgrep -f 'openclaw gateway' > /dev/null 2>&1"; then
        echo "Gateway : running ✓"
        echo "Dashboard: http://localhost:18789/"
        echo ""
        echo "  Set AI model via Dashboard if not configured"
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
