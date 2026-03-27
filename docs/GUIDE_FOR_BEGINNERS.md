# OpenClaw Docker 완전 초보자 가이드

> 컴퓨터를 잘 모르셔도 괜찮습니다. 이 가이드를 처음부터 끝까지 따라하시면 됩니다.

---

## 이게 뭔가요?

OpenClaw는 **AI 비서를 내 컴퓨터에서 돌리는 프로그램**입니다.

이 프로젝트는 OpenClaw를 **가상 컴퓨터** 안에 미리 설치해 놓은 것입니다. 마치 컴퓨터 안에 작은 컴퓨터가 하나 더 있다고 생각하시면 됩니다. 이 가상 컴퓨터는 **웹 브라우저**(크롬, 엣지 등)로 접속해서 사용합니다.

복잡한 설치 과정 없이, 몇 번의 클릭만으로 AI 비서 환경을 바로 사용할 수 있습니다.

---

## 준비물

- 인터넷이 연결된 컴퓨터 (Windows, Mac 또는 Ubuntu)
- ChatGPT Plus/Pro 구독 (유료 결제 중인 OpenAI 계정) **또는** AI API 키

---

## 1단계: Docker Desktop 설치

> Docker는 "가상 컴퓨터를 만들어주는 프로그램"이라고 생각하시면 됩니다. 한 번만 설치하면 됩니다.

### Windows에서 설치

1. 아래 주소를 크롬이나 엣지에서 엽니다:

   ```
   https://www.docker.com/products/docker-desktop/
   ```

2. **"Download for Windows"** 버튼을 클릭합니다.

3. 다운로드된 **Docker Desktop Installer.exe** 파일을 더블클릭합니다.

4. 설치 화면이 나오면 모든 체크박스를 그대로 두고 **OK** → **Close** 를 눌러 설치를 완료합니다.

5. **컴퓨터를 재부팅합니다.** (꼭 해주세요!)

6. 재부팅 후, 바탕화면이나 시작 메뉴에서 **Docker Desktop**을 실행합니다.

7. 처음 실행하면 이용약관 동의 화면이 나옵니다. **Accept** 를 누릅니다.

8. 로그인을 요청하면 **"Continue without signing in"** (로그인 없이 계속) 또는 **Skip** 을 누르면 됩니다.

9. 화면 하단 상태바에 Docker 아이콘(고래 모양)이 보이고, **"Docker Desktop is running"** 이라고 나오면 준비 완료입니다.

### Mac에서 설치

1. 아래 주소를 Safari나 Chrome에서 엽니다:

   ```
   https://www.docker.com/products/docker-desktop/
   ```

2. **"Download for Mac"** 버튼을 클릭합니다.
   - **Apple 칩 (M1/M2/M3/M4)** 인지, **Intel 칩**인지 선택해야 합니다.
   - 모르겠으면: 화면 왼쪽 상단 사과 아이콘 → **"이 Mac에 관하여"** 에서 확인할 수 있습니다. "Apple M~" 이라고 되어 있으면 Apple 칩, "Intel" 이라고 되어 있으면 Intel 칩입니다.

3. 다운로드된 **Docker.dmg** 파일을 더블클릭합니다.

4. Docker 아이콘을 **Applications** 폴더로 드래그합니다.

5. **Launchpad** 또는 **응용 프로그램** 폴더에서 **Docker**를 실행합니다.

6. "시스템 확장을 허용하시겠습니까?" 같은 메시지가 나오면 **허용**합니다.

7. 이용약관 동의 화면이 나오면 **Accept** 를 누릅니다.

8. 로그인을 요청하면 **"Continue without signing in"** 또는 **Skip** 을 누르면 됩니다.

9. 상단 메뉴바에 Docker 아이콘(고래 모양)이 보이고, **"Docker Desktop is running"** 이라고 나오면 준비 완료입니다.

### Ubuntu에서 설치

Ubuntu에서는 Docker Desktop 대신 터미널 명령어로 Docker를 설치합니다.

1. **터미널**을 엽니다. (Ctrl + Alt + T)

2. 아래 명령어를 **한 줄씩 복사**해서 터미널에 붙여넣고 **Enter**를 누릅니다:

   ```bash
   sudo apt-get update
   sudo apt-get install -y ca-certificates curl
   sudo install -m 0755 -d /etc/apt/keyrings
   sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
   sudo chmod a+r /etc/apt/keyrings/docker.asc
   ```

3. 이어서 아래 명령어를 실행합니다:

   ```bash
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
   sudo apt-get update
   sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
   ```

4. Docker를 **재부팅 없이** 바로 사용할 수 있도록 설정합니다:

   ```bash
   sudo usermod -aG docker $USER
   newgrp docker
   ```

5. 설치가 잘 되었는지 확인합니다:

   ```bash
   docker --version
   ```

   `Docker version 2x.x.x` 같은 내용이 나오면 준비 완료입니다.

---

## 2단계: 프로젝트 파일 다운로드

1. 아래 주소에서 프로젝트 파일을 다운로드합니다:

   ```
   https://github.com/neoplanetz/openclaw-desktop-docker
   ```

2. 초록색 **"<> Code"** 버튼을 클릭합니다.

3. **"Download ZIP"** 을 클릭합니다.

4. 다운로드된 ZIP 파일의 압축을 풉니다.
   - **Windows**: 다운로드 폴더에서 ZIP 파일을 우클릭 → **"압축 풀기"** 또는 **"모두 추출"**
   - **Mac**: 다운로드 폴더에서 ZIP 파일을 더블클릭
   - **Ubuntu**: 다운로드 폴더에서 ZIP 파일을 우클릭 → **"여기에 풀기"** 또는 터미널에서 `unzip 파일명.zip`

5. 압축을 푼 폴더를 기억해 두세요. (예: `openclaw-desktop-docker-main` 같은 이름)

---

## 3단계: 가상 컴퓨터 실행하기

### Windows에서 실행

1. 압축을 푼 폴더를 엽니다.

2. 폴더 안의 빈 곳에서 **Shift + 마우스 우클릭** → **"여기에서 PowerShell 창 열기"** 또는 **"여기에서 터미널 열기"** 를 선택합니다.

   > 위 옵션이 안 보이는 경우:
   > 1. 시작 메뉴에서 **"PowerShell"** 을 검색해서 실행합니다.
   > 2. 아래 명령어에서 경로 부분을 자신의 폴더 위치로 바꿔서 입력합니다:
   >    ```
   >    cd C:\Users\내이름\Downloads\openclaw-desktop-docker-main
   >    ```

3. 아래 명령어를 **복사**해서 터미널에 **붙여넣기** 하고 **Enter**를 누릅니다:

   ```
   docker compose up -d --build
   ```

4. 처음 실행하면 필요한 파일을 인터넷에서 다운로드합니다. **10~30분 정도 걸릴 수 있습니다.** (인터넷 속도에 따라 다릅니다)

5. 아래와 같은 메시지가 나오면 성공입니다:

   ```
   ✔ Container openclaw-desktop  Started
   ```

### Mac에서 실행

1. 압축을 푼 폴더를 엽니다.

2. **터미널** 앱을 실행합니다.
   - Spotlight 검색 (Command + Space) → "터미널" 또는 "Terminal" 입력 → Enter

3. 터미널에 `cd ` (cd 뒤에 띄어쓰기 한 칸)를 입력한 후, **Finder에서 압축을 푼 폴더를 터미널 창으로 드래그**합니다. 그러면 경로가 자동으로 입력됩니다. Enter를 누릅니다.

   > 드래그가 안 되면 직접 입력합니다:
   > ```
   > cd ~/Downloads/openclaw-desktop-docker-main
   > ```

4. 아래 명령어를 **복사**해서 터미널에 **붙여넣기** 하고 **Enter**를 누릅니다:

   ```
   docker compose up -d --build
   ```

5. 처음 실행하면 필요한 파일을 인터넷에서 다운로드합니다. **10~30분 정도 걸릴 수 있습니다.**

6. 아래와 같은 메시지가 나오면 성공입니다:

   ```
   ✔ Container openclaw-desktop  Started
   ```

### Ubuntu에서 실행

1. **터미널**을 엽니다. (Ctrl + Alt + T)

2. 압축을 푼 폴더로 이동합니다:

   ```bash
   cd ~/Downloads/openclaw-desktop-docker-main
   ```

3. 아래 명령어를 입력하고 **Enter**를 누릅니다:

   ```
   docker compose up -d --build
   ```

4. 처음 실행하면 필요한 파일을 인터넷에서 다운로드합니다. **10~30분 정도 걸릴 수 있습니다.**

5. 아래와 같은 메시지가 나오면 성공입니다:

   ```
   ✔ Container openclaw-desktop  Started
   ```

---

## 4단계: 가상 컴퓨터에 접속하기

가상 컴퓨터가 실행되면, **지금 쓰고 있는 웹 브라우저**로 접속합니다.

1. 크롬, 엣지, Safari 등 아무 브라우저를 열고, 주소창에 다음을 입력합니다:

   ```
   http://localhost:6080/vnc.html
   ```

2. **"Connect"** 버튼을 클릭합니다.

3. 비밀번호를 물어보면 기본 비밀번호를 입력합니다:

   ```
   claw1234
   ```

   > 이 비밀번호는 기본값입니다. `.env` 파일에서 변경할 수 있습니다.

4. 가상 컴퓨터의 바탕화면이 나타납니다! 일반 컴퓨터처럼 마우스와 키보드로 사용할 수 있습니다.

---

## 5단계: AI 모델 설정하기 (최초 1회)

가상 컴퓨터 바탕화면에 보이는 아이콘 중 **"OpenClaw Setup"** 을 **더블클릭**합니다.

터미널(검은 창)이 열리고 설정 마법사가 시작됩니다. 아래 스크린샷을 따라 진행하세요.

> 아래 예시는 **ChatGPT Plus/Pro 구독**이 있는 경우 기준입니다. API 키를 사용하는 경우에도 흐름은 비슷합니다.

### 5-1. 온보딩 시작

![01](images/01-welcome.png)

**Yes** 를 선택합니다.

### 5-2. QuickStart 선택

![02](images/02-quickstart.png)

**QuickStart** 를 선택합니다.

### 5-3. 설정값 업데이트

![03](images/03-update-values.png)

**Update values** 를 선택합니다.

### 5-4. AI 제공자 선택

![04](images/04-select-openai.png)

**OpenAI** 를 선택합니다.

### 5-5. 인증 방식 선택

![05](images/05-codex-oauth.png)

**OpenAI Codex (ChatGPT OAuth)** 를 선택합니다. ChatGPT Plus/Pro 구독이 있으면 별도의 API 키 없이 바로 사용할 수 있습니다.

### 5-6. 크롬 로그인 팝업

![06](images/06-chrome-signin.png)

크롬 브라우저가 열리면서 로그인 팝업이 나올 수 있습니다. **OK** 를 누르고, **Don't Sign in** 을 선택합니다. (크롬 계정 로그인이 아니라 OpenAI 로그인을 해야 합니다)

### 5-7. OpenAI 로그인

![07](images/07-openai-login.png)

OpenAI 로그인 화면이 나오면 **ChatGPT에서 사용하는 계정**으로 로그인하고 **Continue** 를 누릅니다.

### 5-8. 인증 완료

![08](images/08-auth-complete.png)

![09](images/09-auth-done.png)

인증이 완료되면 위와 같은 화면이 나옵니다. 자동으로 다음 단계로 넘어갑니다.

### 5-9. 기본 모델 선택

![10](images/10-select-model.png)

사용할 AI 모델을 선택합니다. 잘 모르겠으면 **기본값 그대로** 두고 진행하면 됩니다.

### 5-10. 채널 연결 (선택사항)

![11](images/11-select-channel.png)

텔레그램, 디스코드 등 연결할 메신저를 선택합니다. **나중에 해도 되므로 건너뛰어도 됩니다.**

여기서는 텔레그램을 예시로 선택합니다.

### 5-11. 텔레그램 봇 토큰 입력 (텔레그램 선택 시)

![12](images/12-telegram-token.png)

**Enter Telegram bot Token** 을 선택한 후, 자신의 텔레그램 봇 토큰을 입력합니다.

> 텔레그램 봇 토큰은 텔레그램에서 [@BotFather](https://t.me/BotFather)에게 `/newbot` 명령으로 만들 수 있습니다.

### 5-12. 추가 AI 제공자 선택 (선택사항)

![13](images/13-additional-provider.png)

다른 AI 제공자를 추가로 설정할 수 있습니다. 필요 없으면 건너뛰세요.

### 5-13. 추가 API 키 입력 (선택사항)

![14](images/14-additional-apikey.png)

추가 제공자를 선택한 경우 API 키를 입력합니다. 필요 없으면 **그냥 Enter** 를 눌러 건너뜁니다.

### 5-14. 스킬 설치

![15](images/15-skills-confirm.png)

스킬을 설치할지 물어봅니다. **Yes** 를 선택합니다.

![16](images/16-skills-select.png)

원하는 스킬을 **키보드 스페이스바**로 선택한 후, **Enter** 를 눌러 설치합니다.

### 5-15. 스킬 설정

![17](images/17-skills-setup-confirm.png)

스킬 설정을 진행할지 물어봅니다. **Yes** 를 선택합니다.

![18](images/18-skills-apikeys.png)

각 스킬에 필요한 API 키를 입력하거나, 필요 없으면 **No** 를 선택합니다.

### 5-16. Hook 설치

![19](images/19-hooks.png)

Hook(자동화 기능)을 설치할지 물어봅니다. **모두 선택하여 설치하는 것을 추천합니다.**

### 5-17. Gateway 설치 (무시해도 됨)

![20](images/20-gateway-fail.png)

![21](images/21-dashboard-auto.png)

"Gateway daemon install failed" 라는 메시지가 나오지만 **정상입니다. 무시하세요.** 조금 기다리면 자동으로 OpenClaw Dashboard 화면이 열립니다.

### 5-18. 설정 완료 확인

![22](images/22-dashboard-chat.png)

대시보드의 Chat 화면에서 **"Hi"** 를 입력해 보세요. AI가 정상적으로 답변하면 설치가 완료된 것입니다!

---

## 6단계: 텔레그램 연결하기 (텔레그램 설정한 경우)

텔레그램 채널을 설정한 경우, 봇과의 연결을 승인해야 합니다.

### 6-1. 텔레그램에서 봇에게 말 걸기

![23](images/23-telegram-start.png)

![24](images/24-telegram-pairing.png)

![25](images/25-telegram-code.png)

텔레그램에서 자신의 봇을 찾아 대화를 시작합니다. 봇이 **Pairing Code** (승인 코드)를 보내줍니다.

### 6-2. Pairing Code 승인

![26](images/26-pairing-terminal.png)

![27](images/27-pairing-approve.png)

가상 컴퓨터 바탕화면에서 **"OpenClaw Terminal"** 을 더블클릭한 후, 아래 명령어를 입력합니다. `<pairing code>` 부분을 텔레그램에서 받은 코드로 바꿔주세요.

```bash
openclaw pairing approve telegram <pairing code>
```

### 6-3. 텔레그램으로 대화 시작

![28](images/28-telegram-chat.png)

승인이 완료되면 텔레그램에서 자신의 AI 봇과 대화할 수 있습니다!

---

## 7단계: 대시보드 사용하기

설정이 끝났으면 이제 OpenClaw를 사용할 수 있습니다!

### 대시보드(관리 화면) 열기

가상 컴퓨터 바탕화면의 **"OpenClaw Dashboard"** 를 더블클릭하면 관리 화면이 브라우저에 열립니다.

또는, 지금 쓰고 있는 내 컴퓨터의 브라우저에서도 바로 접속할 수 있습니다:

```
http://localhost:18789/
```

---

## 자주 묻는 질문 (FAQ)

### Q: "Gateway daemon install failed" 오류가 떠요

정상입니다! 이 메시지는 무시하셔도 됩니다. 가상 컴퓨터 특성상 나오는 메시지이며, 실제로는 정상 작동합니다.

### Q: 가상 컴퓨터를 끄고 싶어요

터미널(PowerShell 또는 Mac 터미널)에서 프로젝트 폴더로 이동한 뒤:

```
docker compose down
```

설정과 데이터는 그대로 보존됩니다. 다시 켤 때는:

```
docker compose up -d
```

> 처음과 달리 `--build`가 없으므로 바로 실행됩니다.

### Q: Docker Desktop은 항상 켜놔야 하나요?

가상 컴퓨터를 사용하는 동안에만 켜두면 됩니다. Docker Desktop을 종료하면 가상 컴퓨터도 자동으로 꺼집니다.

### Q: 가상 컴퓨터 화면이 안 나와요

1. Docker Desktop이 실행 중인지 확인합니다 (작업 표시줄/메뉴바에 고래 아이콘).
2. 터미널에서 아래 명령어로 상태를 확인합니다:
   ```
   docker compose ps
   ```
   State가 **"running"** 이어야 합니다.
3. 그래도 안 되면 아래 명령어로 다시 시작합니다:
   ```
   docker compose down
   docker compose up -d
   ```

### Q: 비밀번호가 뭐예요?

- 기본 비밀번호: `claw1234`
- 가상 컴퓨터 안에서 관리자 비밀번호를 물어볼 때도 같은 비밀번호를 입력하세요
- 프로젝트 폴더의 `.env` 파일을 수정하면 사용자명과 비밀번호를 변경할 수 있습니다. 변경 후 `docker compose up -d --build`를 실행하세요

### Q: 설정을 처음부터 다시 하고 싶어요

1. 가상 컴퓨터를 끕니다:
   ```
   docker compose down
   ```
2. 저장된 데이터를 삭제합니다:
   ```
   docker volume rm openclaw-home
   ```
3. 다시 시작합니다:
   ```
   docker compose up -d
   ```

> **주의**: 이 경우 가상 컴퓨터 안에 저장한 모든 데이터가 삭제됩니다.

### Q: 브라우저에서 접속했는데 "control ui requires device identity" 라고 나와요

가상 컴퓨터 바탕화면에서 **"OpenClaw Dashboard"** 아이콘을 더블클릭해서 열어주세요. 외부 브라우저에서 직접 주소를 입력하면 이 오류가 나올 수 있습니다.
