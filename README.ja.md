🌐 [English](README.md) | [한국어](README.ko.md) | [中文](README.zh.md) | [日本語](README.ja.md)

# OpenClaw Docker デスクトップ環境

Webブラウザ（NoVNC）、RDP、またはVNC経由でアクセス可能な完全なUbuntu 24.04 GUIデスクトップ内で[OpenClaw](https://openclaw.ai/)を実行するための、すぐに使えるDocker環境です。

Node.js 22、OpenClaw、Google Chrome、デフォルトのGateway設定がすべてプリインストールされています。初回起動時にGatewayが自動的に開始されるので、AIモデルを設定するだけですぐに使用できます。

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/neoplanetz) [![CTEE](https://img.shields.io/badge/CTEE-커피%20한%20잔-FF5722?style=for-the-badge)](https://ctee.kr/place/neoplanetz)

<p>
  <img src="dockerized_openclaw.png" width="49%" />
  <img src="openclaw_desktop_web.png" width="49%" />
</p>

> **Dockerが初めてですか？** スクリーンショット付きの[完全初心者ガイド](GUIDE_FOR_BEGINNERS.ja.md)をご覧ください。

## 含まれるコンポーネント

| コンポーネント | 詳細 |
|-----------|---------|
| **ベースOS** | Ubuntu 24.04 |
| **デスクトップ** | XFCE4（韓国語 + CJK + 絵文字フォント付き） |
| **リモートアクセス** | TigerVNC + NoVNC（Web）、xRDP（リモートデスクトップ）、VNC |
| **ブラウザ** | Google Chrome（デフォルト、`--no-sandbox`ラッパー） |
| **ランタイム** | Node.js 22（NodeSource） |
| **OpenClaw** | npmの最新版、デフォルト設定済み、Gateway自動起動 |
| **デスクトップショートカット** | OpenClawセットアップ、ダッシュボード、ターミナル |

## ポート

| ポート | サービス |
|------|---------|
| `6080` | NoVNC — Webブラウザでデスクトップにアクセス |
| `5901` | VNC — VNCクライアントで直接接続 |
| `3389` | RDP — Windowsリモートデスクトップ / Remmina |
| `18789` | OpenClaw Gateway & ダッシュボード |

## クイックスタート

### 前提条件

- Docker Engine 20+

### ビルドと実行

```bash
docker compose up -d --build
```

または単独実行：
```bash
docker build -t openclaw-desktop .
docker run -d --name openclaw-desktop \
  -p 6080:6080 -p 5901:5901 -p 3389:3389 -p 18789:18789 \
  --shm-size=2g --security-opt seccomp=unconfined \
  openclaw-desktop
```

## デスクトップへの接続

### Webブラウザ（NoVNC）

`http://localhost:6080/vnc.html`を開き、VNCパスワード（`claw1234`）を入力してください。

### RDP（リモートデスクトップ）

任意のRDPクライアントで`localhost:3389`に接続してください：
- **Windows**：`mstsc`
- **macOS**：Microsoft Remote Desktop
- **Linux**：Remmina

ログイン情報：`claw` / `claw1234`（ドメインは空欄のまま）。

### VNCクライアント

任意のVNCビューアで`localhost:5901`に接続してください。

## OpenClawセットアップ

### 仕組み（手動インストール不要）

Dockerイメージには、Node.js 22、OpenClaw、および最小限の`~/.openclaw/openclaw.json`設定が含まれています。コンテナ起動時にエントリポイントが以下を実行します：

1. VNC、NoVNC、xRDPサーバーを起動
2. OpenClaw設定ファイルの存在を確認（欠落時は再生成）
3. バックグラウンドでOpenClaw Gatewayを起動（`openclaw gateway run`）
4. ChromeをXFCEのデフォルトWebブラウザに設定

Dockerにはsystemdがないため、オンボーディング中のGatewayデーモンインストールステップは失敗します — **これは想定通りであり、安全に無視できます**。エントリポイントがGatewayプロセスを直接管理します。

### デスクトップショートカット

XFCEデスクトップに3つのアイコンが配置されます：

| アイコン | 機能 |
|------|-------------|
| **OpenClaw Setup** | `openclaw onboard`を実行 — AIモデル/認証、チャンネル（Telegram、Discordなど）、スキルを設定します。最後のGatewayデーモンインストール失敗は正常です。 |
| **OpenClaw Dashboard** | `openclaw dashboard`を実行 — 正しい`localhost` URLと自動ログイントークンでChromeを開きます。 |
| **OpenClaw Terminal** | `openclaw` CLIが使えるXFCEターミナルを開きます。 |

### 初回AIモデル設定

デスクトップの**「OpenClaw Setup」**をダブルクリックしてください。オンボーディングウィザードが以下を案内します：

1. **モデル / 認証** — プロバイダーを選択（OpenAI Codex OAuth、Anthropic APIキーなど）
2. **チャンネル** — Telegram、Discord、WhatsAppを接続またはスキップ
3. **スキル** — 推奨スキルをインストールまたはスキップ
4. **Gatewayデーモン** — 失敗します（systemdなし）— 無視してください

ウィザード完了後、Gatewayが自動的に再起動し、ダッシュボードが開きます。

#### OpenAI Codex OAuth（ChatGPTサブスクリプション）

ChatGPT Plus/Proサブスクリプションをお持ちの場合、オンボーディング中に**「OpenAI Codex (ChatGPT OAuth)」**を選択してください。ブラウザウィンドウが開き、OpenAIアカウントにログインします。認証後、モデルが自動的に設定されます。

またはターミナルで直接実行：
```bash
openclaw models auth login --provider openai-codex --set-default
```

#### Anthropic APIキー

```bash
openclaw config set agents.defaults.model.primary anthropic/claude-sonnet-4-6
echo 'ANTHROPIC_API_KEY=sk-ant-...' >> ~/.openclaw/.env
```

#### OpenAI APIキー

```bash
openclaw config set agents.defaults.model.primary openai/gpt-4o
echo 'OPENAI_API_KEY=sk-...' >> ~/.openclaw/.env
```

### Gateway管理

```bash
openclaw status              # 全体ステータス
openclaw gateway status      # Gatewayステータス
openclaw models status       # モデル/認証ステータス
openclaw config get          # 現在の設定を表示
openclaw dashboard           # 自動ログイントークンでダッシュボードを開く
```

## 設定

### デフォルト `openclaw.json`

`~/.openclaw/openclaw.json`にプリセット：

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

- `bind: "lan"` — すべてのインターフェースでリッスンし、ホストが`http://localhost:18789/`にアクセス可能
- `controlUi.allowedOrigins: ["*"]` — 任意のオリジンからのダッシュボードアクセスを許可（Docker内部で必要）
- デフォルトではAIモデルは設定されていません — オンボーディングまたはCLIで設定してください

### 環境変数

| 変数 | デフォルト | 説明 |
|----------|---------|-------------|
| `USER` | `claw` | Linuxユーザー名 |
| `PASSWORD` | `claw1234` | VNC / RDP / sudoパスワード |
| `VNC_RESOLUTION` | `1920x1080` | デスクトップ解像度 |
| `VNC_COL_DEPTH` | `24` | 色深度 |
| `TZ` | `Asia/Seoul` | タイムゾーン |

## データの永続化

`openclaw-home`名前付きボリュームが`/home/claw`にマウントされます。以下が保持されます：

- OpenClaw設定、認証情報、会話履歴
- Chromeプロファイルとブックマーク
- デスクトップのカスタマイズ
- SSHキー、シェル履歴など

`docker compose down` / `up`後もデータは保持されます。`docker volume rm openclaw-home`のみがデータを削除します。

## Docker固有の回避策

このセットアップには、Docker内でフルGUI + ブラウザ + OpenClawを実行するためのいくつかの回避策が含まれています：

| 問題 | 解決策 |
|-------|----------|
| systemdなし | エントリポイントがVNC、xRDP、Gatewayプロセスを直接管理 |
| Chromeにサンドボックスが必要 | ラッパースクリプトがすべての起動に`--no-sandbox`を追加 |
| `xdg-open`がDocker内部IPを使用 | ラッパーが`172.x.x.x` / `10.x.x.x` URLを`localhost`に書き換え |
| ブラウザがターミナルから切り離される | xdg-openラッパーの`setsid`がターミナル終了時のSIGHUPを防止 |
| Chromeプロファイルのロック競合 | コンテナ起動時に古い`SingletonLock`ファイルをクリーンアップ |
| XFCEデフォルトブラウザ | 起動ごとにカスタムexo-helper + `mimeapps.list`を設定 |
| VNCパスワード（`vncpasswd`なし） | 3段階フォールバック：`vncpasswd`バイナリ → `openssl` → 純粋なPython DES |
| DockerでFirefox snapが動作しない | Google Chrome debパッケージに置き換え |

## トラブルシューティング

### コンテナが再起動を繰り返す
```bash
docker compose logs openclaw-desktop
```
VNC起動または設定検証のエラーを確認してください。

### NoVNCに空白画面が表示される
```bash
docker exec -it openclaw-desktop bash
su - claw -c "vncserver -kill :1"
su - claw -c "vncserver :1 -geometry 1920x1080 -depth 24 -localhost no"
```

### RDPに白い画面が表示される
```bash
docker exec -it openclaw-desktop /etc/init.d/xrdp restart
```

### OpenClaw Gatewayが動作していない
```bash
docker exec -u claw openclaw-desktop openclaw status
# 手動再起動：
docker exec -u claw openclaw-desktop bash -c \
  "nohup openclaw gateway run >> ~/.openclaw/gateway.log 2>&1 & disown"
```

### オンボーディング中に「Gateway daemon install failed」
これは想定通りです — Dockerコンテナにはsystemdがありません。エントリポイントが代わりにGatewayのライフサイクルを管理します。このメッセージは無視してください。

### ダッシュボードに「control ui requires device identity」が表示される
ブラウザが`localhost`ではなくDocker内部IPで開かれました。閉じて**「OpenClaw Dashboard」**デスクトップショートカットを使用してください。正しいURLとトークンで`openclaw dashboard`を実行します。

## ファイル構成

```
openclaw-docker/
├── Dockerfile              # Ubuntu 24.04ベースイメージ
├── docker-compose.yml      # Compose設定
├── entrypoint.sh           # ランタイム：VNC、xRDP、Chrome設定、Gateway
├── dockerized_openclaw.png # デスクトップ壁紙 & READMEプレビュー
├── .gitignore
└── README.md
```
