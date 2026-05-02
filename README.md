# OpenClaw + OpenCode Dev Bridge v1.0

## Mobile-First AI Development Workflow for Windows

A single-click installer that sets up an AI-powered development bridge on your Windows PC. Control it from Telegram — build code, review PRs, push to GitHub, all from your phone.

---

## Quick Start

### Option A: PowerShell (recommended)
```powershell
# Right-click PowerShell -> Run as Administrator
cd C:\path\to\download
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\install.ps1
```
Enter your keys when prompted. Done in 10-25 minutes.

### Option B: Batch file
1. **Download** `install.bat` 
2. **Right-click → Run as Administrator**
3. **Answer prompts**

If `install.bat` shows garbled characters or hangs, use Option A instead.

What gets installed:
- Node.js (via winget, if missing)
- Git (via winget, if missing)
- Ollama (optional, for local AI models)
- openclaw + opencode-ai + pm2 (npm packages)
- OpenClaw Dev Bridge config + PM2 daemon

**Time:** ~10-25 minutes | **Disk:** ~7-10 GB (mostly npm + Ollama model)

---

## Prerequisites (gather before running)

| Item | Where to get it |
|------|----------------|
| **Telegram Bot Token** | Message `@BotFather` → `/newbot` → copy token |
| **Telegram User ID** | Message `@userinfobot` → copy your numeric ID |
| **OpenCode API Key** | Go to https://opencode.ai/auth → sign in → API Keys |

---

## Telegram Commands

| Command | Description | What happens |
|---------|-------------|--------------|
| `/ask hello` | Ask anything | Direct LLM response in Telegram |
| `/beta Build a REST API with FastAPI` | Generate code | Dispatches to OpenCode ACP agent |
| `/plan Login with JWT` | Get design docs | Replies with PRD + spec, no code |
| `/status` | Check queue | Counts pending/in-progress/done tasks |
| `/push` | Git push | Stages, commits, pushes current work |
| `/review` | Code review | Reviews last diff in repo, reports issues |

---

## Management

```powershell
pm2 logs openclaw-gw        # Real-time gateway logs
pm2 restart openclaw-gw     # Restart after config changes
pm2 stop openclaw-gw        # Shutdown
pm2 status                  # Show all processes
```

- Gateway URL: `http://127.0.0.1:18789`
- Config: `%USERPROFILE%\.openclaw\openclaw.json`
- Logs: `%TEMP%\openclaw\`
- Task queue: `%USERPROFILE%\.openclaw\tasks\`

---

## System Requirements

- **Windows 10/11 x64**
- **Node.js >= 22.14** (auto-installed if missing)
- **Git** (auto-installed if missing)
- **Ollama** (optional — for local AI models)
- **Internet** — for Telegram API + npm packages + cloud LLMs

---

## First Run Example

```
1. Send to your bot: /ask what is your role
   → Bot replies: "PM for the dev dispatch hub..."

2. Send: /beta Create a hello-world Python script in C:\Dev\Projects\hello
   → Bot ack, dispatches, returns result

3. Send: /status
   → Shows: "1 done, 0 pending"

4. Send: /push
   → Git add + commit + push to remote
```

---

## Troubleshooting

### Gateway won't start
```powershell
pm2 logs openclaw-gw --lines 50
```
Check `%TEMP%\openclaw\` for error logs.

### Telegram bot not responding
1. Verify token in `%USERPROFILE%\.openclaw\openclaw.json` → `channels.telegram.botToken`
2. Verify your user ID is in `allowFrom` array
3. Restart: `pm2 restart openclaw-gw`

### Node.js install fails via winget
Download from https://nodejs.org (LTS), then re-run `install.bat`.

### Ollama model download stuck
Skip Ollama during setup and use cloud models only. Add to config:
```json
"models": { "providers": { "openrouter": { ... } } }
```

---

## Files

```
install.bat          ← Run this
openclaw.template.json   ← Config template (for reference)
ecosystem.config.cjs     ← PM2 config (for reference)
```

---

## Version

v1.0 — May 2026

## Author

Pedot
