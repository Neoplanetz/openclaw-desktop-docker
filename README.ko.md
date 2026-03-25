🌐 [English](README.md) | [한국어](README.ko.md) | [中文](README.zh.md) | [日本語](README.ja.md)

# OpenClaw Docker 데스크톱 환경

웹 브라우저(NoVNC), RDP 또는 VNC를 통해 접속 가능한 Ubuntu 24.04 GUI 데스크톱 안에서 [OpenClaw](https://openclaw.ai/)를 실행하는 올인원 Docker 환경입니다.

Node.js 22, OpenClaw, Google Chrome, 기본 Gateway 설정이 모두 사전 설치되어 있습니다. 첫 부팅 시 Gateway가 자동으로 시작되므로, AI 모델만 설정하면 바로 사용할 수 있습니다.

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/neoplanetz) [![CTEE](https://img.shields.io/badge/CTEE-커피%20한%20잔-FF5722?style=for-the-badge)](https://ctee.kr/place/neoplanetz)

<p>
  <img src="dockerized_openclaw.png" width="49%" />
  <img src="openclaw_desktop_web.png" width="49%" />
</p>

> **Docker가 처음이신가요?** 스크린샷과 함께 하나하나 따라할 수 있는 [완전 초보자 가이드](GUIDE_FOR_BEGINNERS.md)를 확인해 보세요.

## 포함 구성 요소

| 구성 요소 | 세부 사항 |
|-----------|---------|
| **기본 OS** | Ubuntu 24.04 |
| **데스크톱** | XFCE4 (한국어 + CJK + 이모지 폰트 포함) |
| **원격 접속** | TigerVNC + NoVNC (웹), xRDP (원격 데스크톱), VNC |
| **브라우저** | Google Chrome (기본, `--no-sandbox` 래퍼) |
| **런타임** | Node.js 22 (NodeSource) |
| **OpenClaw** | npm 최신 버전, 기본 설정 사전 구성, Gateway 자동 시작 |
| **바탕화면 바로가기** | OpenClaw 설정, 대시보드, 터미널 |

## 포트

| 포트 | 서비스 |
|------|---------|
| `6080` | NoVNC — 웹 브라우저로 데스크톱 접속 |
| `5901` | VNC — VNC 클라이언트 직접 연결 |
| `3389` | RDP — Windows 원격 데스크톱 / Remmina |
| `18789` | OpenClaw Gateway & 대시보드 |

## 빠른 시작

### 사전 요구 사항

- Docker Engine 20+

### Docker Hub에서 실행 (권장)

```bash
docker compose up -d
```

또는 단독 실행:
```bash
docker pull neoplanetz/openclaw-desktop-docker:latest
docker run -d --name openclaw-desktop \
  -p 6080:6080 -p 5901:5901 -p 3389:3389 -p 18789:18789 \
  --shm-size=2g --security-opt seccomp=unconfined \
  neoplanetz/openclaw-desktop-docker:latest
```

### 소스에서 직접 빌드

이미지를 직접 빌드하려면:
```bash
docker compose up -d --build
```

## 데스크톱 연결 방법

### 웹 브라우저 (NoVNC)

`http://localhost:6080/vnc.html`을 열고 VNC 비밀번호(`claw1234`)를 입력하세요.

### RDP (원격 데스크톱)

아무 RDP 클라이언트로 `localhost:3389`에 접속하세요:
- **Windows**: `mstsc`
- **macOS**: Microsoft Remote Desktop
- **Linux**: Remmina

로그인 정보: `claw` / `claw1234` (도메인은 비워두세요).

### VNC 클라이언트

아무 VNC 뷰어로 `localhost:5901`에 접속하세요.

## OpenClaw 설정

### 작동 방식 (수동 설치 불필요)

Docker 이미지에 Node.js 22, OpenClaw, 최소 `~/.openclaw/openclaw.json` 설정이 포함되어 있습니다. 컨테이너 시작 시마다 엔트리포인트가 다음을 수행합니다:

1. VNC, NoVNC, xRDP 서버 시작
2. OpenClaw 설정 파일 존재 확인 (없으면 재생성)
3. 백그라운드에서 OpenClaw Gateway 시작 (`openclaw gateway run`)
4. Chrome을 XFCE 기본 웹 브라우저로 설정

Docker에는 systemd가 없으므로, 온보딩 중 Gateway 데몬 설치 단계는 실패합니다 — **이는 정상이며 무시해도 됩니다**. 엔트리포인트가 Gateway 프로세스를 직접 관리합니다.

### 바탕화면 바로가기

XFCE 바탕화면에 세 개의 아이콘이 배치됩니다:

| 아이콘 | 기능 |
|------|-------------|
| **OpenClaw Setup** | `openclaw onboard` 실행 — AI 모델/인증, 채널(Telegram, Discord 등), 스킬을 구성합니다. 마지막에 Gateway 데몬 설치 실패는 정상입니다. |
| **OpenClaw Dashboard** | `openclaw dashboard` 실행 — 올바른 `localhost` URL과 자동 로그인 토큰으로 Chrome을 엽니다. |
| **OpenClaw Terminal** | `openclaw` CLI가 준비된 XFCE 터미널을 엽니다. |

### 최초 AI 모델 설정

바탕화면의 **"OpenClaw Setup"**을 더블클릭하세요. 온보딩 마법사가 다음을 안내합니다:

1. **모델 / 인증** — 제공자 선택 (OpenAI Codex OAuth, Anthropic API 키 등)
2. **채널** — Telegram, Discord, WhatsApp 연결 또는 건너뛰기
3. **스킬** — 추천 스킬 설치 또는 건너뛰기
4. **Gateway 데몬** — 실패함 (systemd 없음) — 무시하세요

마법사가 완료되면 자동으로 Gateway를 재시작하고 대시보드를 엽니다.

#### OpenAI Codex OAuth (ChatGPT 구독)

ChatGPT Plus/Pro 구독이 있다면, 온보딩 중 **"OpenAI Codex (ChatGPT OAuth)"**를 선택하세요. 브라우저 창이 열리면 OpenAI 계정으로 로그인합니다. 인증 후 모델이 자동 설정됩니다.

또는 터미널에서 직접 실행:
```bash
openclaw models auth login --provider openai-codex --set-default
```

#### Anthropic API 키

```bash
openclaw config set agents.defaults.model.primary anthropic/claude-sonnet-4-6
echo 'ANTHROPIC_API_KEY=sk-ant-...' >> ~/.openclaw/.env
```

#### OpenAI API 키

```bash
openclaw config set agents.defaults.model.primary openai/gpt-4o
echo 'OPENAI_API_KEY=sk-...' >> ~/.openclaw/.env
```

### Gateway 관리

```bash
openclaw status              # 전체 상태
openclaw gateway status      # Gateway 상태
openclaw models status       # 모델/인증 상태
openclaw config get          # 현재 설정 보기
openclaw dashboard           # 자동 로그인 토큰으로 대시보드 열기
```

## 설정

### 기본 `openclaw.json`

`~/.openclaw/openclaw.json`에 사전 구성:

```json5
{
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
```

- `bind: "lan"` — 모든 인터페이스에서 수신하여 호스트가 `http://localhost:18789/`에 접근 가능
- `controlUi.allowedOrigins: ["*"]` — 모든 오리진에서 대시보드 접근 허용 (Docker 내부에서 필요)
- 기본적으로 AI 모델은 설정되어 있지 않음 — 온보딩 또는 CLI로 설정하세요

### 환경 변수

| 변수 | 기본값 | 설명 |
|----------|---------|-------------|
| `USER` | `claw` | Linux 사용자명 |
| `PASSWORD` | `claw1234` | VNC / RDP / sudo 비밀번호 |
| `VNC_RESOLUTION` | `1920x1080` | 데스크톱 해상도 |
| `VNC_COL_DEPTH` | `24` | 색 심도 |
| `TZ` | `Asia/Seoul` | 시간대 |

## 데이터 영속성

`openclaw-home` 네임드 볼륨이 `/home/claw`에 마운트됩니다. 다음이 보존됩니다:

- OpenClaw 설정, 인증 정보, 대화 기록
- Chrome 프로필 및 북마크
- 데스크톱 사용자 지정
- SSH 키, 셸 히스토리 등

`docker compose down` / `up` 후에도 데이터가 유지됩니다. `docker volume rm openclaw-home`만이 데이터를 삭제합니다.

## Docker 관련 우회 방법

이 환경에는 Docker 안에서 전체 GUI + 브라우저 + OpenClaw를 실행하기 위한 여러 우회 방법이 포함되어 있습니다:

| 문제 | 해결 방법 |
|-------|----------|
| systemd 없음 | 엔트리포인트가 VNC, xRDP, Gateway 프로세스를 직접 관리 |
| Chrome 샌드박스 필요 | 래퍼 스크립트가 모든 실행에 `--no-sandbox` 추가 |
| `xdg-open`이 Docker 내부 IP 사용 | 래퍼가 `172.x.x.x` / `10.x.x.x` URL을 `localhost`로 변환 |
| 브라우저가 터미널에서 분리 | xdg-open 래퍼의 `setsid`가 터미널 종료 시 SIGHUP 방지 |
| Chrome 프로필 잠금 충돌 | 컨테이너 시작 시 오래된 `SingletonLock` 파일 정리 |
| XFCE 기본 브라우저 | 매 시작 시 커스텀 exo-helper + `mimeapps.list` 설정 |
| VNC 비밀번호 (`vncpasswd` 없음) | 3단계 폴백: `vncpasswd` 바이너리 → `openssl` → 순수 Python DES |
| Docker에서 Firefox snap 미작동 | Google Chrome deb 패키지로 대체 |

## 문제 해결

### 컨테이너가 계속 재시작됨
```bash
docker compose logs openclaw-desktop
```
VNC 시작 또는 설정 검증 오류를 확인하세요.

### NoVNC에 빈 화면이 표시됨
```bash
docker exec -it openclaw-desktop bash
su - claw -c "vncserver -kill :1"
su - claw -c "vncserver :1 -geometry 1920x1080 -depth 24 -localhost no"
```

### RDP에 흰 화면이 표시됨
```bash
docker exec -it openclaw-desktop /etc/init.d/xrdp restart
```

### OpenClaw Gateway가 실행되지 않음
```bash
docker exec -u claw openclaw-desktop openclaw status
# 수동 재시작:
docker exec -u claw openclaw-desktop bash -c \
  "nohup openclaw gateway run >> ~/.openclaw/gateway.log 2>&1 & disown"
```

### 온보딩 중 "Gateway daemon install failed"
이는 정상입니다 — Docker 컨테이너에는 systemd가 없습니다. 엔트리포인트가 대신 Gateway 생명주기를 관리합니다. 이 메시지를 무시하세요.

### 대시보드에 "control ui requires device identity" 표시
브라우저가 `localhost` 대신 Docker 내부 IP로 열렸습니다. 닫고 **"OpenClaw Dashboard"** 바탕화면 바로가기를 사용하세요. 올바른 URL과 토큰으로 `openclaw dashboard`를 실행합니다.

## 파일 구조

```
openclaw-docker/
├── Dockerfile              # Ubuntu 24.04 베이스 이미지
├── docker-compose.yml      # Compose 설정
├── entrypoint.sh           # 런타임: VNC, xRDP, Chrome 설정, Gateway
├── dockerized_openclaw.png # 데스크톱 배경화면 & README 미리보기
├── .gitignore
└── README.md
```
