# OpenClaw Docker Beginner's Guide

> Don't worry if you're not very tech-savvy. Just follow this guide from start to finish.

---

## What is this?

OpenClaw is a **program that runs an AI assistant on your own computer**.

This project comes with OpenClaw **pre-installed inside a virtual computer**. Think of it like having a small computer running inside your computer. You access this virtual computer through a **web browser** (Chrome, Edge, etc.).

No complicated installation process — you can have your AI assistant environment up and running with just a few clicks.

---

## What you need

- A computer with an internet connection (Windows, Mac, or Ubuntu)
- A ChatGPT Plus/Pro subscription (a paid OpenAI account) **or** an AI API key

---

## Step 1: Install Docker Desktop

> Think of Docker as "a program that creates virtual computers." You only need to install it once.

### Installing on Windows

1. Open the following address in Chrome or Edge:

   ```
   https://www.docker.com/products/docker-desktop/
   ```

2. Click the **"Download for Windows"** button.

3. Double-click the downloaded **Docker Desktop Installer.exe** file.

4. When the installation screen appears, leave all checkboxes as they are and click **OK** → **Close** to complete the installation.

5. **Restart your computer.** (This is required!)

6. After restarting, launch **Docker Desktop** from the desktop or Start menu.

7. The first time you run it, you will see a terms of service screen. Click **Accept**.

8. If asked to log in, click **"Continue without signing in"** or **Skip**.

9. When you see the Docker icon (a whale) in the taskbar at the bottom of the screen and it says **"Docker Desktop is running"**, you are ready.

### Installing on Mac

1. Open the following address in Safari or Chrome:

   ```
   https://www.docker.com/products/docker-desktop/
   ```

2. Click the **"Download for Mac"** button.
   - You need to choose whether you have an **Apple chip (M1/M2/M3/M4)** or an **Intel chip**.
   - If you're not sure: click the Apple icon in the top-left corner of your screen → **"About This Mac"**. If it says "Apple M~", you have an Apple chip. If it says "Intel", you have an Intel chip.

3. Double-click the downloaded **Docker.dmg** file.

4. Drag the Docker icon into the **Applications** folder.

5. Launch **Docker** from **Launchpad** or the **Applications** folder.

6. If a message appears asking something like "Allow system extension?", click **Allow**.

7. When the terms of service screen appears, click **Accept**.

8. If asked to log in, click **"Continue without signing in"** or **Skip**.

9. When you see the Docker icon (a whale) in the top menu bar and it says **"Docker Desktop is running"**, you are ready.

### Installing on Ubuntu

On Ubuntu, you install Docker using terminal commands instead of Docker Desktop.

1. Open a **Terminal**. (Ctrl + Alt + T)

2. Copy the commands below **one line at a time**, paste them into the terminal, and press **Enter**:

   ```bash
   sudo apt-get update
   sudo apt-get install -y ca-certificates curl
   sudo install -m 0755 -d /etc/apt/keyrings
   sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
   sudo chmod a+r /etc/apt/keyrings/docker.asc
   ```

3. Then run the following commands:

   ```bash
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
   sudo apt-get update
   sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
   ```

4. Configure Docker so you can use it immediately **without restarting**:

   ```bash
   sudo usermod -aG docker $USER
   newgrp docker
   ```

5. Verify the installation was successful:

   ```bash
   docker --version
   ```

   If you see something like `Docker version 2x.x.x`, you are ready.

---

## Step 2: Download the project files

1. Download the project files from the address below:

   ```
   https://github.com/neoplanetz/openclaw-desktop-docker
   ```

2. Click the green **"<> Code"** button.

3. Click **"Download ZIP"**.

4. Extract the downloaded ZIP file.
   - **Windows**: In the Downloads folder, right-click the ZIP file → **"Extract All"** or **"Extract Here"**
   - **Mac**: In the Downloads folder, double-click the ZIP file
   - **Ubuntu**: In the Downloads folder, right-click the ZIP file → **"Extract Here"**, or in the terminal run `unzip filename.zip`

5. Remember where you extracted the folder. (It will have a name like `openclaw-desktop-docker-main`)

---

## Step 3: Start the virtual computer

### Starting on Windows

1. Open the extracted folder.

2. **Shift + right-click** on an empty area inside the folder → select **"Open PowerShell window here"** or **"Open Terminal here"**.

   > If you don't see that option:
   > 1. Search for **"PowerShell"** in the Start menu and open it.
   > 2. In the command below, replace the path with the actual location of your folder:
   >    ```
   >    cd C:\Users\YourName\Downloads\openclaw-desktop-docker-main
   >    ```

3. **Copy** the command below, **paste** it into the terminal, and press **Enter**:

   ```
   docker compose up -d --build
   ```

4. The first time you run this, it will download the necessary files from the internet. **This may take 10 to 30 minutes** depending on your internet speed.

5. When you see a message like the one below, it was successful:

   ```
   ✔ Container openclaw-desktop  Started
   ```

### Starting on Mac

1. Open the extracted folder.

2. Launch the **Terminal** app.
   - Spotlight search (Command + Space) → type "Terminal" → press Enter

3. In the terminal, type `cd ` (cd followed by a space), then **drag the extracted folder from Finder into the terminal window**. The path will be filled in automatically. Press Enter.

   > If dragging doesn't work, type it manually:
   > ```
   > cd ~/Downloads/openclaw-desktop-docker-main
   > ```

4. **Copy** the command below, **paste** it into the terminal, and press **Enter**:

   ```
   docker compose up -d --build
   ```

5. The first time you run this, it will download the necessary files from the internet. **This may take 10 to 30 minutes.**

6. When you see a message like the one below, it was successful:

   ```
   ✔ Container openclaw-desktop  Started
   ```

### Starting on Ubuntu

1. Open a **Terminal**. (Ctrl + Alt + T)

2. Navigate to the extracted folder:

   ```bash
   cd ~/Downloads/openclaw-desktop-docker-main
   ```

3. Enter the following command and press **Enter**:

   ```
   docker compose up -d --build
   ```

4. The first time you run this, it will download the necessary files from the internet. **This may take 10 to 30 minutes.**

5. When you see a message like the one below, it was successful:

   ```
   ✔ Container openclaw-desktop  Started
   ```

---

## Step 4: Connect to the virtual computer

Once the virtual computer is running, connect to it using the **web browser you already have open**.

1. Open any browser — Chrome, Edge, Safari, etc. — and type the following in the address bar:

   ```
   http://localhost:6080/vnc.html
   ```

2. Click the **"Connect"** button.

3. If prompted for a password, enter:

   ```
   claw1234
   ```

4. The virtual computer's desktop will appear! You can use it with your mouse and keyboard just like a regular computer.

---

## Step 5: Configure the AI model (first-time only)

On the virtual computer's desktop, find the **"OpenClaw Setup"** icon and **double-click** it.

A terminal (black window) will open and the setup wizard will start. Follow the screenshots below.

> The example below is based on having a **ChatGPT Plus/Pro subscription**. The flow is similar if you are using an API key.

### 5-1. Start onboarding

![01](guide_images/01-welcome.png)

Select **Yes**.

### 5-2. Select QuickStart

![02](guide_images/02-quickstart.png)

Select **QuickStart**.

### 5-3. Update values

![03](guide_images/03-update-values.png)

Select **Update values**.

### 5-4. Select AI provider

![04](guide_images/04-select-openai.png)

Select **OpenAI**.

### 5-5. Select authentication method

![05](guide_images/05-codex-oauth.png)

Select **OpenAI Codex (ChatGPT OAuth)**. If you have a ChatGPT Plus/Pro subscription, you can use it right away without a separate API key.

### 5-6. Chrome sign-in popup

![06](guide_images/06-chrome-signin.png)

A Chrome browser window may open with a sign-in popup. Click **OK**, then select **Don't Sign in**. (You need to sign in with OpenAI, not a Chrome account.)

### 5-7. OpenAI login

![07](guide_images/07-openai-login.png)

When the OpenAI login screen appears, sign in with the **account you use for ChatGPT** and click **Continue**.

### 5-8. Authentication complete

![08](guide_images/08-auth-complete.png)

![09](guide_images/09-auth-done.png)

When authentication is complete, you will see a screen like the one above. It will automatically proceed to the next step.

### 5-9. Select default model

![10](guide_images/10-select-model.png)

Choose the AI model you want to use. If you're not sure, just leave the **default selection** and continue.

### 5-10. Connect a channel (optional)

![11](guide_images/11-select-channel.png)

Choose a messaging app to connect, such as Telegram or Discord. **You can do this later, so feel free to skip it for now.**

Here, Telegram is used as an example.

### 5-11. Enter Telegram bot token (if Telegram is selected)

![12](guide_images/12-telegram-token.png)

Select **Enter Telegram bot Token**, then enter your Telegram bot token.

> You can create a Telegram bot token by messaging [@BotFather](https://t.me/BotFather) on Telegram and using the `/newbot` command.

### 5-12. Select additional AI provider (optional)

![13](guide_images/13-additional-provider.png)

You can optionally add another AI provider. Skip this if you don't need it.

### 5-13. Enter additional API key (optional)

![14](guide_images/14-additional-apikey.png)

If you selected an additional provider, enter its API key. If you don't need it, just press **Enter** to skip.

### 5-14. Install skills

![15](guide_images/15-skills-confirm.png)

You will be asked whether to install skills. Select **Yes**.

![16](guide_images/16-skills-select.png)

Use the **keyboard spacebar** to select the skills you want, then press **Enter** to install them.

### 5-15. Configure skills

![17](guide_images/17-skills-setup-confirm.png)

You will be asked whether to proceed with skill configuration. Select **Yes**.

![18](guide_images/18-skills-apikeys.png)

Enter the API key required for each skill, or select **No** if you don't need it.

### 5-16. Install hooks

![19](guide_images/19-hooks.png)

You will be asked whether to install hooks (automation features). **It is recommended to select all and install them.**

### 5-17. Gateway installation (can be ignored)

![20](guide_images/20-gateway-fail.png)

![21](guide_images/21-dashboard-auto.png)

You may see a message saying "Gateway daemon install failed", but **this is normal. You can ignore it.** After a moment, the OpenClaw Dashboard will open automatically.

### 5-18. Confirm setup is complete

![22](guide_images/22-dashboard-chat.png)

In the Chat section of the dashboard, try typing **"Hi"**. If the AI responds normally, the installation is complete!

---

## Step 6: Connect Telegram (if Telegram was configured)

If you set up a Telegram channel, you need to approve the connection with your bot.

### 6-1. Message your bot on Telegram

![23](guide_images/23-telegram-start.png)

![24](guide_images/24-telegram-pairing.png)

![25](guide_images/25-telegram-code.png)

Find your bot on Telegram and start a conversation. The bot will send you a **Pairing Code**.

### 6-2. Approve the Pairing Code

![26](guide_images/26-pairing-terminal.png)

![27](guide_images/27-pairing-approve.png)

On the virtual computer's desktop, double-click **"OpenClaw Terminal"** and enter the command below. Replace `<pairing code>` with the code you received from Telegram.

```bash
openclaw pairing approve telegram <pairing code>
```

### 6-3. Start chatting on Telegram

![28](guide_images/28-telegram-chat.png)

Once approved, you can chat with your AI bot directly on Telegram!

---

## Step 7: Using the dashboard

Once setup is complete, you are ready to use OpenClaw!

### Opening the dashboard (management screen)

Double-click **"OpenClaw Dashboard"** on the virtual computer's desktop to open the management screen in a browser.

You can also access it directly from the browser on your own computer:

```
http://localhost:18789/
```

---

## Frequently Asked Questions (FAQ)

### Q: I'm getting a "Gateway daemon install failed" error

That's normal! You can safely ignore this message. It appears due to the nature of the virtual computer environment, but everything works fine in practice.

### Q: How do I shut down the virtual computer?

In a terminal (PowerShell or Mac Terminal), navigate to the project folder and run:

```
docker compose down
```

Your settings and data will be preserved. To start it again:

```
docker compose up -d
```

> Note that there is no `--build` this time, so it will start right away.

### Q: Does Docker Desktop need to stay open all the time?

It only needs to be running while you are using the virtual computer. If you close Docker Desktop, the virtual computer will automatically shut down as well.

On Ubuntu, Docker runs as a system service, so no separate app needs to stay open.

### Q: The virtual computer screen isn't showing up

1. Check that Docker Desktop is running (look for the whale icon in the taskbar or menu bar).
2. In a terminal, check the status with this command:
   ```
   docker compose ps
   ```
   The State should show **"running"**.
3. If it still doesn't work, restart with these commands:
   ```
   docker compose down
   docker compose up -d
   ```

### Q: What is the password?

- Password to access the virtual computer: `claw1234`
- If asked for an administrator password inside the virtual computer: `claw1234`

### Q: I want to start the setup from scratch

1. Shut down the virtual computer:
   ```
   docker compose down
   ```
2. Delete the saved data:
   ```
   docker volume rm openclaw-home
   ```
3. Start it again:
   ```
   docker compose up -d
   ```

> **Warning**: This will delete all data saved inside the virtual computer.

### Q: When I access from a browser, it says "control ui requires device identity"

Please open the dashboard by double-clicking the **"OpenClaw Dashboard"** icon on the virtual computer's desktop. Typing the address directly into an external browser can cause this error.
