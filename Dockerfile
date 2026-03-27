# ============================================================
# OpenClaw Docker Environment
# Ubuntu 24.04 + XFCE4 + NoVNC + xRDP
# ============================================================
FROM ubuntu:24.04

LABEL maintainer="openclaw-docker"
LABEL description="OpenClaw with Ubuntu GUI (NoVNC + RDP)"

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
    VNC_COL_DEPTH=24

# ── Base packages + locale ─────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    locales \
    && sed -i 's/# ko_KR.UTF-8/ko_KR.UTF-8/' /etc/locale.gen \
    && locale-gen ko_KR.UTF-8 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── XFCE4 desktop + essential tools ───────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Desktop
    xfce4 \
    xfce4-terminal \
    xfce4-goodies \
    dbus-x11 \
    # VNC
    tigervnc-standalone-server \
    tigervnc-common \
    tigervnc-tools \
    # RDP
    xrdp \
    xorgxrdp \
    xserver-xorg-core \
    # NoVNC + websockify
    novnc \
    websockify \
    # System utilities
    sudo \
    wget \
    curl \
    git \
    nano \
    vim \
    htop \
    net-tools \
    ca-certificates \
    gnupg \
    lsb-release \
    procps \
    openssl \
    # Python
    python3 \
    python3-pip \
    python3-venv \
    # CJK + emoji fonts
    fonts-nanum \
    fonts-nanum-coding \
    fonts-noto-cjk \
    fonts-noto-color-emoji \
    # X11 misc
    xauth \
    x11-utils \
    software-properties-common \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── Google Chrome (deb package) ────────────────────────────
# Chrome has many deps, install without --no-install-recommends
RUN wget -q -O /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get update \
    && apt-get install -y /tmp/google-chrome.deb \
    || (apt-get -f install -y && apt-get install -y /tmp/google-chrome.deb) \
    && rm -f /tmp/google-chrome.deb \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Chrome always needs --no-sandbox inside Docker
# Wrap original binary + clean stale lock files
RUN mv /usr/bin/google-chrome-stable /usr/bin/google-chrome-stable-real

RUN printf '#!/bin/bash\nexec /usr/bin/google-chrome-stable-real --no-sandbox "$@"\n' \
    > /usr/bin/google-chrome-stable \
    && chmod +x /usr/bin/google-chrome-stable \
    && rm -f /usr/bin/google-chrome 2>/dev/null; \
       cp /usr/bin/google-chrome-stable /usr/bin/google-chrome

# ── Set Chrome as default browser ─────────────────────────
RUN update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/google-chrome-stable 200 \
    && update-alternatives --set x-www-browser /usr/bin/google-chrome-stable \
    && update-alternatives --install /usr/bin/gnome-www-browser gnome-www-browser /usr/bin/google-chrome-stable 200 \
    && update-alternatives --set gnome-www-browser /usr/bin/google-chrome-stable

# ── xdg-open wrapper (Docker internal IP → localhost) ────
# Onboard opens browser with 172.x.x.x which fails secure context
# Wrapper rewrites Docker internal IPs to localhost
RUN mv /usr/bin/xdg-open /usr/bin/xdg-open-real 2>/dev/null || true

RUN echo '#!/bin/bash' > /usr/bin/xdg-open \
    && echo 'URL="$1"' >> /usr/bin/xdg-open \
    && echo 'URL=$(echo "$URL" | sed -E "s#https?://172\.[0-9]+\.[0-9]+\.[0-9]+#http://localhost#")' >> /usr/bin/xdg-open \
    && echo 'URL=$(echo "$URL" | sed -E "s#https?://10\.[0-9]+\.[0-9]+\.[0-9]+#http://localhost#")' >> /usr/bin/xdg-open \
    && echo 'setsid /usr/bin/xdg-open-real "$URL" &' >> /usr/bin/xdg-open \
    && chmod +x /usr/bin/xdg-open

# ── Node.js 22 (baked into image, persists across restarts) ─────
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && node --version && npm --version

# ── OpenClaw (baked into image, onboard on first run) ──
RUN npm install -g openclaw@latest \
    && echo "OpenClaw $(openclaw --version 2>/dev/null || echo 'installed')"

# ── vncpasswd binary check/symlink ────────────────────────
# Binary name/path may differ across packages
RUN echo "=== VNC binary lookup ===" \
    && find / -name "*vncpasswd*" -type f 2>/dev/null || true \
    && (which vncpasswd && echo "vncpasswd OK") \
    || (which tigervncpasswd && ln -sf $(which tigervncpasswd) /usr/local/bin/vncpasswd && echo "tigervncpasswd → symlinked") \
    || echo "WARN: vncpasswd not found, will use Python fallback at runtime"

# ── Create user ───────────────────────────────────────────
RUN useradd -m -s /bin/bash ${USER} \
    && echo "${USER}:${PASSWORD}" | chpasswd \
    && adduser ${USER} sudo \
    && echo "${USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/${USER}

# ── OpenClaw default config (model excluded — set via Dashboard) ───
RUN mkdir -p /home/${USER}/.openclaw/workspace \
    && cat > /home/${USER}/.openclaw/openclaw.json << 'CLAWCFG'
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

RUN chown -R ${USER}:${USER} /home/${USER}/.openclaw \
    && chmod 700 /home/${USER}/.openclaw \
    && chmod 600 /home/${USER}/.openclaw/openclaw.json

# ── Desktop shortcuts ──────────────────────────────────
RUN mkdir -p /home/${USER}/Desktop

# 1) OpenClaw Setup script + desktop shortcut
RUN printf '#!/bin/bash\n\
echo "========================================"\n\
echo " OpenClaw Setup (Onboarding)"\n\
echo "========================================"\n\
echo ""\n\
openclaw onboard\n\
echo ""\n\
read\n' > /usr/local/bin/openclaw-setup.sh \
    && chmod +x /usr/local/bin/openclaw-setup.sh

RUN printf '[Desktop Entry]\n\
Version=1.0\n\
Type=Application\n\
Name=OpenClaw Setup\n\
Comment=OpenClaw onboarding (AI model, channels, skills)\n\
Exec=xfce4-terminal -e "openclaw-setup.sh"\n\
Icon=preferences-system\n\
Terminal=false\n\
Categories=Utility;\n' > /home/${USER}/Desktop/openclaw-setup.desktop \
    && chmod +x /home/${USER}/Desktop/openclaw-setup.desktop

# 2) OpenClaw Dashboard
RUN printf '[Desktop Entry]\n\
Version=1.0\n\
Type=Application\n\
Name=OpenClaw Dashboard\n\
Comment=OpenClaw Dashboard (web browser)\n\
Exec=openclaw dashboard\n\
Icon=web-browser\n\
Terminal=false\n\
Categories=Network;\n' > /home/${USER}/Desktop/openclaw-dashboard.desktop \
    && chmod +x /home/${USER}/Desktop/openclaw-dashboard.desktop

# 3) OpenClaw Terminal (CLI)
RUN printf '[Desktop Entry]\n\
Version=1.0\n\
Type=Application\n\
Name=OpenClaw Terminal\n\
Comment=OpenClaw CLI terminal\n\
Exec=xfce4-terminal -e "bash -c '\''openclaw; exec bash'\''"\n\
Icon=utilities-terminal\n\
Terminal=false\n\
Categories=Utility;\n' > /home/${USER}/Desktop/openclaw-terminal.desktop \
    && chmod +x /home/${USER}/Desktop/openclaw-terminal.desktop

RUN chown -R ${USER}:${USER} /home/${USER}/Desktop

# ── Desktop wallpaper ─────────────────────────────────
# 1) Replace default XFCE background (system path, unaffected by volume mounts)
COPY assets/dockerized_openclaw.png /usr/share/backgrounds/xfce/xfce-teal.jpg
COPY assets/dockerized_openclaw.png /usr/share/backgrounds/dockerized_openclaw.png

# ── VNC directory + xstartup (password set at runtime) ─
RUN mkdir -p /home/${USER}/.vnc \
    && printf '#!/bin/bash\nunset SESSION_MANAGER\nunset DBUS_SESSION_BUS_ADDRESS\nexec dbus-launch --exit-with-session startxfce4\n' \
       > /home/${USER}/.vnc/xstartup \
    && chmod +x /home/${USER}/.vnc/xstartup \
    && chown -R ${USER}:${USER} /home/${USER}/.vnc

# ── xRDP config ─────────────────────────────────────────────
RUN sed -i 's/^#xserverbpp=24/xserverbpp=24/' /etc/xrdp/xrdp.ini \
    && echo "xfce4-session" > /home/${USER}/.xsession \
    && chown ${USER}:${USER} /home/${USER}/.xsession

# ── Save user config templates (for dynamic user creation at runtime) ──
RUN mkdir -p /opt/openclaw-defaults \
    && cp -a /home/${USER}/.vnc /opt/openclaw-defaults/ \
    && cp -a /home/${USER}/.openclaw /opt/openclaw-defaults/ \
    && cp -a /home/${USER}/Desktop /opt/openclaw-defaults/ \
    && cp -a /home/${USER}/.xsession /opt/openclaw-defaults/

# Replace startwm.sh with XFCE4 (xRDP session startup)
RUN printf '#!/bin/bash\n\
unset DBUS_SESSION_BUS_ADDRESS\n\
unset XDG_RUNTIME_DIR\n\
if [ -r /etc/profile ]; then\n\
    . /etc/profile\n\
fi\n\
exec dbus-launch --exit-with-session startxfce4\n' > /etc/xrdp/startwm.sh \
    && chmod +x /etc/xrdp/startwm.sh

# ── NoVNC symlink (unified path) ─────────────────────────
RUN ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html 2>/dev/null || true

# ── Entrypoint script ─────────────────────────────────────────
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# ── Expose ports ─────────────────────────────────────────────
# 6080: NoVNC (web browser)
# 5901: VNC direct connection
# 3389: RDP
# 8080: OpenClaw Gateway
EXPOSE 6080 5901 3389 18789

ENTRYPOINT ["/entrypoint.sh"]