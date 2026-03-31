# OpenClaw Docker Desktop Environment

A turnkey Docker setup for running [OpenClaw](https://openclaw.ai/) inside a full Ubuntu 24.04 GUI desktop, accessible via web browser (NoVNC), RDP, or VNC.

Everything is pre-installed — Node.js 22, OpenClaw, Google Chrome, and a default Gateway config. On first boot the Gateway starts automatically; just set your AI model and go.

![OpenClaw Desktop](https://raw.githubusercontent.com/neoplanetz/openclaw-desktop-docker/main/assets/dockerized_openclaw.png)

> **Full documentation & Beginner's Guide:** [GitHub Repository](https://github.com/neoplanetz/openclaw-desktop-docker)

> **Support this project:** [Buy Me A Coffee](https://buymeacoffee.com/neoplanetz) | [CTEE (커피 한 잔)](https://ctee.kr/place/neoplanetz)

## Architecture

![Architecture](https://raw.githubusercontent.com/neoplanetz/openclaw-desktop-docker/main/assets/architecture_en.svg)

## What's Included

| Component | Details |
|-----------|---------|
| **Base OS** | Ubuntu 24.04 |
| **Desktop** | XFCE4 with Korean + CJK + emoji fonts |
| **Remote Access** | TigerVNC + NoVNC (web), xRDP (Remote Desktop), raw VNC |
| **Browser** | Google Chrome |
| **Runtime** | Node.js 22 |
| **OpenClaw** | Latest from npm, Gateway auto-starts on boot |
| **Desktop Shortcuts** | OpenClaw Setup, Dashboard, Terminal |

## Ports

| Port | Service |
|------|---------|
| `6080` | NoVNC — access the desktop via web browser |
| `5901` | VNC — direct VNC client connection |
| `3389` | RDP — Windows Remote Desktop / Remmina |
| `18789` | OpenClaw Gateway & Dashboard |

## Quick Start

### Docker Compose (Recommended)

```bash
docker compose up -d
```

### Standalone

```bash
docker run -d --name openclaw-desktop \
  -p 6080:6080 -p 5901:5901 -p 3389:3389 -p 18789:18789 \
  --shm-size=2g --security-opt seccomp=unconfined \
  neoplanetz/openclaw-desktop-docker:latest
```

## Connecting to the Desktop

| Method | Address | Credentials |
|--------|---------|-------------|
| **NoVNC (Web)** | `http://localhost:6080/vnc.html` | Password: `claw1234` |
| **RDP** | `localhost:3389` | `claw` / `claw1234` |
| **VNC** | `localhost:5901` | Password: `claw1234` |

## Custom Username & Password

Edit the `.env` file in the project root:

```env
CLAW_USER=myname
CLAW_PASSWORD=mypassword
```

Then rebuild:

```bash
docker compose up -d --build
```

## First-Time AI Model Setup

Double-click **"OpenClaw Setup"** on the desktop. The onboarding wizard walks through:

1. **Model / Auth** — choose a provider (OpenAI Codex OAuth, Anthropic API key, etc.)
2. **Channels** — connect Telegram, Discord, WhatsApp, or skip
3. **Skills** — install recommended skills or skip

Or configure via CLI:

```bash
# OpenAI Codex (ChatGPT Plus/Pro subscription)
openclaw models auth login --provider openai-codex --set-default

# Anthropic API Key
openclaw config set agents.defaults.model.primary anthropic/claude-sonnet-4-6
echo 'ANTHROPIC_API_KEY=sk-ant-...' >> ~/.openclaw/.env

# OpenAI API Key
openclaw config set agents.defaults.model.primary openai/gpt-4o
echo 'OPENAI_API_KEY=sk-...' >> ~/.openclaw/.env
```

## Environment Variables

| `.env` Variable | Container Env | Default | Description |
|----------|---------|---------|-------------|
| `CLAW_USER` | `USER` | `claw` | Linux username |
| `CLAW_PASSWORD` | `PASSWORD` | `claw1234` | VNC / RDP / sudo password |
| — | `VNC_RESOLUTION` | `1920x1080` | Desktop resolution |
| — | `VNC_COL_DEPTH` | `24` | Color depth |
| — | `TZ` | `Asia/Seoul` | Timezone |
| `OPENCLAW_BROWSER_ENABLED` | `OPENCLAW_BROWSER_ENABLED` | `false` | Enable OpenClaw CDP browser (Chrome profile: `openclaw`) |
| `OPENCLAW_DISPLAY_TARGET` | `OPENCLAW_DISPLAY_TARGET` | `auto` | Display targeting policy: `auto`, `vnc`, `rdp` |

## Data Persistence

Mount a volume to `/home/claw` to persist OpenClaw config, credentials, conversation history, and desktop customizations:

```bash
docker run -d --name openclaw-desktop \
  -v openclaw-home:/home/claw \
  -p 6080:6080 -p 5901:5901 -p 3389:3389 -p 18789:18789 \
  --shm-size=2g --security-opt seccomp=unconfined \
  neoplanetz/openclaw-desktop-docker:latest
```

## Links

- [GitHub Repository](https://github.com/neoplanetz/openclaw-desktop-docker) — Full documentation, Beginner's Guides (EN, KO, ZH, JA), and source code
- [OpenClaw](https://openclaw.ai/) — Official OpenClaw website
