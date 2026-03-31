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
    VNC_COL_DEPTH=24 \
    OPENCLAW_DISPLAY_TARGET=auto

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
ARG OPENCLAW_VERSION=latest
RUN npm install -g openclaw@${OPENCLAW_VERSION} \
    && echo "OpenClaw $(openclaw --version 2>/dev/null || echo 'installed')"

# ── Verify vncpasswd is available ────────────────────────
RUN which vncpasswd || (which tigervncpasswd && ln -sf $(which tigervncpasswd) /usr/local/bin/vncpasswd) \
    || (echo "ERROR: vncpasswd not found" && exit 1)

# ── Create user ───────────────────────────────────────────
RUN useradd -m -s /bin/bash ${USER} \
    && echo "${USER}:${PASSWORD}" | chpasswd \
    && adduser ${USER} sudo \
    && echo "${USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/${USER}

# ── OpenClaw default config (model excluded — set via Dashboard) ───
RUN mkdir -p /home/${USER}/.openclaw/workspace
COPY configs/openclaw.json /home/${USER}/.openclaw/openclaw.json
RUN chown -R ${USER}:${USER} /home/${USER}/.openclaw \
    && chmod 700 /home/${USER}/.openclaw \
    && chmod 600 /home/${USER}/.openclaw/openclaw.json

# ── Desktop shortcuts ──────────────────────────────────
COPY configs/openclaw-setup.sh /usr/local/bin/openclaw-setup.sh
RUN chmod +x /usr/local/bin/openclaw-setup.sh

RUN mkdir -p /home/${USER}/Desktop
COPY configs/desktop/*.desktop /home/${USER}/Desktop/
RUN chmod +x /home/${USER}/Desktop/*.desktop \
    && chown -R ${USER}:${USER} /home/${USER}/Desktop

# ── Desktop wallpaper ─────────────────────────────────
# 1) Replace default XFCE background (system path, unaffected by volume mounts)
COPY assets/dockerized_openclaw.png /usr/share/backgrounds/xfce/xfce-teal.jpg
COPY assets/dockerized_openclaw.png /usr/share/backgrounds/dockerized_openclaw.png

# ── VNC directory + xstartup (password set at runtime) ─
RUN mkdir -p /home/${USER}/.vnc
COPY configs/vnc/xstartup /home/${USER}/.vnc/xstartup
RUN chmod +x /home/${USER}/.vnc/xstartup \
    && chown -R ${USER}:${USER} /home/${USER}/.vnc

# ── xRDP config ─────────────────────────────────────────────
RUN sed -i 's/^#xserverbpp=24/xserverbpp=24/' /etc/xrdp/xrdp.ini \
    && echo "xfce4-session" > /home/${USER}/.xsession \
    && chown ${USER}:${USER} /home/${USER}/.xsession

# ── Save user config templates (for dynamic user creation at runtime) ──
# /opt/openclaw-defaults/  — user home template (copied to new users)
# /opt/openclaw-configs/   — read-only config templates (entrypoint regeneration)
RUN mkdir -p /opt/openclaw-defaults \
    && cp -a /home/${USER}/.vnc /opt/openclaw-defaults/ \
    && cp -a /home/${USER}/.openclaw /opt/openclaw-defaults/ \
    && cp -a /home/${USER}/Desktop /opt/openclaw-defaults/ \
    && cp -a /home/${USER}/.xsession /opt/openclaw-defaults/
COPY configs/ /opt/openclaw-configs/

# Replace startwm.sh with XFCE4 (xRDP session startup)
COPY configs/xrdp/startwm.sh /etc/xrdp/startwm.sh
COPY configs/xrdp/reconnectwm.sh /etc/xrdp/reconnectwm.sh
RUN chmod +x /etc/xrdp/startwm.sh /etc/xrdp/reconnectwm.sh

# ── NoVNC symlink (unified path) ─────────────────────────
RUN ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html 2>/dev/null || true

# ── Display sync helper (policy-based display targeting) ─────
COPY scripts/openclaw-sync-display /usr/local/bin/openclaw-sync-display
RUN chmod +x /usr/local/bin/openclaw-sync-display

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