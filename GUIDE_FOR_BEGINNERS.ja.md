# OpenClaw Docker 完全初心者ガイド

> コンピュータに詳しくなくても大丈夫です。このガイドを最初から最後まで順番に進めていけばOKです。

---

## これは何ですか？

OpenClaw は **AI アシスタントを自分のコンピュータで動かすプログラム**です。

このプロジェクトは、OpenClaw を**仮想コンピュータ**の中にあらかじめインストールしておいたものです。コンピュータの中に小さなコンピュータがもう一台あると思ってください。この仮想コンピュータは**ウェブブラウザ**（Chrome、Edge など）で接続して使います。

複雑なインストール作業なしに、数回クリックするだけで AI アシスタント環境をすぐに使い始められます。

---

## 準備するもの

- インターネットに接続されたコンピュータ（Windows、Mac または Ubuntu）
- ChatGPT Plus/Pro サブスクリプション（有料プランの OpenAI アカウント） **または** AI API キー

---

## ステップ 1: Docker Desktop のインストール

> Docker は「仮想コンピュータを作ってくれるプログラム」と考えてください。一度インストールすれば OK です。

### Windows でのインストール

1. 以下のアドレスを Chrome または Edge で開きます:

   ```
   https://www.docker.com/products/docker-desktop/
   ```

2. **"Download for Windows"** ボタンをクリックします。

3. ダウンロードされた **Docker Desktop Installer.exe** ファイルをダブルクリックします。

4. インストール画面が表示されたら、すべてのチェックボックスをそのままにして **OK** → **Close** を押してインストールを完了します。

5. **コンピュータを再起動します。**（必ず行ってください！）

6. 再起動後、デスクトップまたはスタートメニューから **Docker Desktop** を起動します。

7. 初回起動時に利用規約の同意画面が表示されます。**Accept** を押します。

8. ログインを求められたら **"Continue without signing in"**（サインインせずに続ける）または **Skip** を押してください。

9. 画面下部のタスクバーに Docker アイコン（クジラのマーク）が表示され、**"Docker Desktop is running"** と出たら準備完了です。

### Mac でのインストール

1. 以下のアドレスを Safari または Chrome で開きます:

   ```
   https://www.docker.com/products/docker-desktop/
   ```

2. **"Download for Mac"** ボタンをクリックします。
   - **Apple チップ（M1/M2/M3/M4）** か **Intel チップ** かを選ぶ必要があります。
   - わからない場合: 画面左上のリンゴアイコン → **"この Mac について"** で確認できます。「Apple M~」と表示されていれば Apple チップ、「Intel」と表示されていれば Intel チップです。

3. ダウンロードされた **Docker.dmg** ファイルをダブルクリックします。

4. Docker アイコンを **Applications** フォルダにドラッグします。

5. **Launchpad** または **アプリケーション** フォルダから **Docker** を起動します。

6. 「システム拡張を許可しますか？」のようなメッセージが表示されたら**許可**します。

7. 利用規約の同意画面が表示されたら **Accept** を押します。

8. ログインを求められたら **"Continue without signing in"** または **Skip** を押してください。

9. 上部メニューバーに Docker アイコン（クジラのマーク）が表示され、**"Docker Desktop is running"** と出たら準備完了です。

### Ubuntu でのインストール

Ubuntu では Docker Desktop の代わりに、ターミナルのコマンドで Docker をインストールします。

1. **ターミナル**を開きます。（Ctrl + Alt + T）

2. 以下のコマンドを**一行ずつコピー**してターミナルに貼り付け、**Enter** を押します:

   ```bash
   sudo apt-get update
   sudo apt-get install -y ca-certificates curl
   sudo install -m 0755 -d /etc/apt/keyrings
   sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
   sudo chmod a+r /etc/apt/keyrings/docker.asc
   ```

3. 続けて以下のコマンドを実行します:

   ```bash
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
   sudo apt-get update
   sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
   ```

4. Docker を**再起動なし**ですぐに使えるように設定します:

   ```bash
   sudo usermod -aG docker $USER
   newgrp docker
   ```

5. インストールが正しくできたか確認します:

   ```bash
   docker --version
   ```

   `Docker version 2x.x.x` のような内容が表示されたら準備完了です。

---

## ステップ 2: プロジェクトファイルのダウンロード

1. 以下のアドレスからプロジェクトファイルをダウンロードします:

   ```
   https://github.com/neoplanetz/openclaw-desktop-docker
   ```

2. 緑色の **"<> Code"** ボタンをクリックします。

3. **"Download ZIP"** をクリックします。

4. ダウンロードされた ZIP ファイルを解凍します。
   - **Windows**: ダウンロードフォルダで ZIP ファイルを右クリック → **「展開」** または **「すべて展開」**
   - **Mac**: ダウンロードフォルダで ZIP ファイルをダブルクリック
   - **Ubuntu**: ダウンロードフォルダで ZIP ファイルを右クリック → **「ここに展開」** またはターミナルで `unzip ファイル名.zip`

5. 解凍したフォルダの場所を覚えておいてください。（例: `openclaw-desktop-docker-main` のような名前）

---

## ステップ 3: 仮想コンピュータを起動する

### Windows での起動

1. 解凍したフォルダを開きます。

2. フォルダ内の空白部分で **Shift + 右クリック** → **「PowerShell ウィンドウをここで開く」** または **「ターミナルをここで開く」** を選択します。

   > 上記のオプションが表示されない場合:
   > 1. スタートメニューで **「PowerShell」** を検索して起動します。
   > 2. 以下のコマンドのパス部分を自分のフォルダの場所に変えて入力します:
   >    ```
   >    cd C:\Users\ユーザー名\Downloads\openclaw-desktop-docker-main
   >    ```

3. 以下のコマンドを**コピー**してターミナルに**貼り付け**、**Enter** を押します:

   ```
   docker compose up -d --build
   ```

4. 初回起動時は必要なファイルをインターネットからダウンロードします。**10〜30分ほどかかる場合があります。**（インターネットの速度によって異なります）

5. 以下のようなメッセージが表示されたら成功です:

   ```
   ✔ Container openclaw-desktop  Started
   ```

### Mac での起動

1. 解凍したフォルダを開きます。

2. **ターミナル** アプリを起動します。
   - Spotlight 検索（Command + Space）→「ターミナル」または「Terminal」と入力 → Enter

3. ターミナルに `cd `（cd の後にスペース一つ）を入力してから、**Finder で解凍したフォルダをターミナルウィンドウにドラッグ**します。すると、パスが自動的に入力されます。Enter を押します。

   > ドラッグできない場合は直接入力します:
   > ```
   > cd ~/Downloads/openclaw-desktop-docker-main
   > ```

4. 以下のコマンドを**コピー**してターミナルに**貼り付け**、**Enter** を押します:

   ```
   docker compose up -d --build
   ```

5. 初回起動時は必要なファイルをインターネットからダウンロードします。**10〜30分ほどかかる場合があります。**

6. 以下のようなメッセージが表示されたら成功です:

   ```
   ✔ Container openclaw-desktop  Started
   ```

### Ubuntu での起動

1. **ターミナル**を開きます。（Ctrl + Alt + T）

2. 解凍したフォルダに移動します:

   ```bash
   cd ~/Downloads/openclaw-desktop-docker-main
   ```

3. 以下のコマンドを入力して **Enter** を押します:

   ```
   docker compose up -d --build
   ```

4. 初回起動時は必要なファイルをインターネットからダウンロードします。**10〜30分ほどかかる場合があります。**

5. 以下のようなメッセージが表示されたら成功です:

   ```
   ✔ Container openclaw-desktop  Started
   ```

---

## ステップ 4: 仮想コンピュータに接続する

仮想コンピュータが起動したら、**今使っているウェブブラウザ**で接続します。

1. Chrome、Edge、Safari など任意のブラウザを開き、アドレスバーに以下を入力します:

   ```
   http://localhost:6080/vnc.html
   ```

2. **"Connect"** ボタンをクリックします。

3. パスワードを求められたらデフォルトのパスワードを入力します:

   ```
   claw1234
   ```

   > これはデフォルトのパスワードです。`.env`ファイルで変更できます。

4. 仮想コンピュータのデスクトップが表示されます！通常のコンピュータと同じようにマウスとキーボードで操作できます。

---

## ステップ 5: AI モデルを設定する（初回のみ）

仮想コンピュータのデスクトップに表示されているアイコンの中から **"OpenClaw Setup"** を**ダブルクリック**します。

ターミナル（黒い画面）が開き、セットアップウィザードが始まります。以下のスクリーンショットに従って進めてください。

> 以下の例は **ChatGPT Plus/Pro サブスクリプション**がある場合を基準にしています。API キーを使用する場合も、流れは同様です。

### 5-1. オンボーディングの開始

![01](guide_images/01-welcome.png)

**Yes** を選択します。

### 5-2. QuickStart の選択

![02](guide_images/02-quickstart.png)

**QuickStart** を選択します。

### 5-3. 設定値の更新

![03](guide_images/03-update-values.png)

**Update values** を選択します。

### 5-4. AI プロバイダーの選択

![04](guide_images/04-select-openai.png)

**OpenAI** を選択します。

### 5-5. 認証方式の選択

![05](guide_images/05-codex-oauth.png)

**OpenAI Codex (ChatGPT OAuth)** を選択します。ChatGPT Plus/Pro サブスクリプションがあれば、別途 API キーなしですぐに使えます。

### 5-6. Chrome ログインのポップアップ

![06](guide_images/06-chrome-signin.png)

Chrome ブラウザが開き、ログインのポップアップが表示される場合があります。**OK** を押し、**Don't Sign in** を選択します。（Chrome アカウントへのログインではなく、OpenAI へのログインが必要です）

### 5-7. OpenAI へのログイン

![07](guide_images/07-openai-login.png)

OpenAI のログイン画面が表示されたら、**ChatGPT で使用しているアカウント**でログインし、**Continue** を押します。

### 5-8. 認証の完了

![08](guide_images/08-auth-complete.png)

![09](guide_images/09-auth-done.png)

認証が完了すると、上記のような画面が表示されます。自動的に次のステップに進みます。

### 5-9. デフォルトモデルの選択

![10](guide_images/10-select-model.png)

使用する AI モデルを選択します。よくわからない場合は**デフォルトのまま**進めてください。

### 5-10. チャンネルの接続（任意）

![11](guide_images/11-select-channel.png)

Telegram、Discord などの接続するメッセンジャーを選択します。**後から設定できるので、スキップしても構いません。**

ここでは Telegram を例として選択します。

### 5-11. Telegram ボットトークンの入力（Telegram を選択した場合）

![12](guide_images/12-telegram-token.png)

**Enter Telegram bot Token** を選択した後、自分の Telegram ボットトークンを入力します。

> Telegram ボットトークンは、Telegram の [@BotFather](https://t.me/BotFather) に `/newbot` コマンドで作成できます。

### 5-12. 追加 AI プロバイダーの選択（任意）

![13](guide_images/13-additional-provider.png)

他の AI プロバイダーを追加で設定できます。必要なければスキップしてください。

### 5-13. 追加 API キーの入力（任意）

![14](guide_images/14-additional-apikey.png)

追加のプロバイダーを選択した場合は API キーを入力します。必要なければ **そのまま Enter** を押してスキップします。

### 5-14. スキルのインストール

![15](guide_images/15-skills-confirm.png)

スキルをインストールするか確認されます。**Yes** を選択します。

![16](guide_images/16-skills-select.png)

インストールしたいスキルを**キーボードのスペースバー**で選択し、**Enter** を押してインストールします。

### 5-15. スキルの設定

![17](guide_images/17-skills-setup-confirm.png)

スキルの設定を進めるか確認されます。**Yes** を選択します。

![18](guide_images/18-skills-apikeys.png)

各スキルに必要な API キーを入力するか、必要なければ **No** を選択します。

### 5-16. Hook のインストール

![19](guide_images/19-hooks.png)

Hook（自動化機能）をインストールするか確認されます。**すべて選択してインストールすることをおすすめします。**

### 5-17. Gateway のインストール（無視して OK）

![20](guide_images/20-gateway-fail.png)

![21](guide_images/21-dashboard-auto.png)

「Gateway daemon install failed」というメッセージが表示されますが、**正常です。無視してください。** しばらく待つと、自動的に OpenClaw Dashboard の画面が開きます。

### 5-18. 設定完了の確認

![22](guide_images/22-dashboard-chat.png)

ダッシュボードの Chat 画面で **「Hi」** と入力してみてください。AI が正常に返答すれば、インストール完了です！

---

## ステップ 6: Telegram を接続する（Telegram を設定した場合）

Telegram チャンネルを設定した場合、ボットとの接続を承認する必要があります。

### 6-1. Telegram でボットに話しかける

![23](guide_images/23-telegram-start.png)

![24](guide_images/24-telegram-pairing.png)

![25](guide_images/25-telegram-code.png)

Telegram で自分のボットを探して会話を始めます。ボットが **Pairing Code**（承認コード）を送ってきます。

### 6-2. Pairing Code の承認

![26](guide_images/26-pairing-terminal.png)

![27](guide_images/27-pairing-approve.png)

仮想コンピュータのデスクトップで **「OpenClaw Terminal」** をダブルクリックし、以下のコマンドを入力します。`<pairing code>` の部分を Telegram で受け取ったコードに置き換えてください。

```bash
openclaw pairing approve telegram <pairing code>
```

### 6-3. Telegram で会話を開始する

![28](guide_images/28-telegram-chat.png)

承認が完了したら、Telegram で自分の AI ボットと会話できます！

---

## ステップ 7: ダッシュボードを使う

設定が終わったら、OpenClaw を使い始めましょう！

### ダッシュボード（管理画面）を開く

仮想コンピュータのデスクトップにある **"OpenClaw Dashboard"** をダブルクリックすると、管理画面がブラウザで開きます。

または、今使っている自分のコンピュータのブラウザから直接アクセスすることもできます:

```
http://localhost:18789/
```

---

## よくある質問（FAQ）

### Q: 「Gateway daemon install failed」というエラーが表示されます

正常です！このメッセージは無視していただいて問題ありません。仮想コンピュータの特性上表示されるメッセージであり、実際には正常に動作しています。

### Q: 仮想コンピュータを終了したいです

ターミナル（PowerShell または Mac のターミナル）でプロジェクトフォルダに移動してから:

```
docker compose down
```

設定とデータはそのまま保持されます。再度起動するときは:

```
docker compose up -d
```

> 初回と異なり `--build` がないため、すぐに起動します。

### Q: Docker Desktop は常に起動しておく必要がありますか？

仮想コンピュータを使用している間だけ起動しておけば OK です。Docker Desktop を終了すると、仮想コンピュータも自動的に停止します。

Ubuntuでは、DockerはシステムサービスとしてはたらくためDockerを使うのに別途アプリを起動しておく必要はありません。

### Q: 仮想コンピュータの画面が表示されません

1. Docker Desktop が起動しているか確認します（タスクバー/メニューバーにクジラのアイコン）。
2. ターミナルで以下のコマンドで状態を確認します:
   ```
   docker compose ps
   ```
   State が **"running"** になっている必要があります。
3. それでも解決しない場合は、以下のコマンドで再起動します:
   ```
   docker compose down
   docker compose up -d
   ```

### Q: パスワードは何ですか？

- デフォルトのパスワード: `claw1234`
- 仮想コンピュータ内で管理者パスワードを求められた場合も同じパスワードを入力してください
- プロジェクトフォルダの`.env`ファイルを編集してユーザー名とパスワードを変更できます。変更後は`docker compose up -d --build`を実行してください

### Q: 設定を最初からやり直したいです

1. 仮想コンピュータを停止します:
   ```
   docker compose down
   ```
2. 保存されたデータを削除します:
   ```
   docker volume rm openclaw-home
   ```
3. 再起動します:
   ```
   docker compose up -d
   ```

> **注意**: この操作を行うと、仮想コンピュータ内に保存したすべてのデータが削除されます。

### Q: ブラウザでアクセスしたら「control ui requires device identity」と表示されます

仮想コンピュータのデスクトップにある **"OpenClaw Dashboard"** アイコンをダブルクリックして開いてください。外部のブラウザから直接アドレスを入力するとこのエラーが表示される場合があります。
