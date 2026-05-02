# OpenClaw Dev Bridge

Mobile-first AI development workflow. Issue commands from Telegram, execute on your Windows PC. OpenClaw is the PM brain, OpenCode does the heavy lifting.

---

## Quick Start

### One-liner

```powershell
powershell -c "irm https://raw.githubusercontent.com/firyomaefx/openclaw-dev-bridge/master/install.ps1 | iex"
```

Works on Windows 10/11 x64. Installs Node.js, Git, OpenClaw, OpenCode, PM2, and Ollama (optional). Just follow the prompts.

### Hackable

```powershell
git clone https://github.com/firyomaefx/openclaw-dev-bridge.git
cd openclaw-dev-bridge
.\install.ps1
```

### Beta

Switch to pre-release channel later with `openclaw update --channel beta`.

---

## Prerequisites

Gather these before running the installer:

| Item | Source |
|------|--------|
| Telegram Bot Token | `@BotFather` on Telegram → `/newbot` |
| Telegram User ID | `@userinfobot` on Telegram → send any message |
| OpenCode API Key | https://opencode.ai/auth → sign in → API Keys |

---

## Telegram Commands

| Command | Does | Response time |
|---------|------|--------------|
| `/ask hello` | Direct LLM answer | < 15s |
| `/beta Build a REST API` | Dispatch to OpenCode ACP | < 2 min |
| `/plan Feature name` | Get PRD + spec breakdown | < 30s |
| `/status` | View task queue counts | < 5s |
| `/push` | Git add + commit + push | < 1 min |
| `/review` | Code review last diff | < 2 min |

---

## Management

```powershell
pm2 logs openclaw-gw        # Real-time gateway logs
pm2 restart openclaw-gw     # Restart after config changes
pm2 stop openclaw-gw        # Shutdown
pm2 delete openclaw-gw      # Remove from PM2
```

- **Gateway:** http://127.0.0.1:18789
- **Config:** `%USERPROFILE%\.openclaw\openclaw.json`
- **Task queue:** `%USERPROFILE%\.openclaw\tasks\`
- **Logs:** `%TEMP%\openclaw\`

---

## System Requirements

| Component | Required | Auto-installed |
|-----------|----------|---------------|
| Windows 10/11 x64 | Yes | — |
| Node.js >= 22.14 | Yes | winget |
| Git >= 2.30 | Yes | winget |
| Ollama | Optional | winget |
| Disk space | ~10 GB | — |

---

## Troubleshooting

**Garbled text in terminal?** Use `install.ps1` (PowerShell) instead of `install.bat`.

**Gateway won't start?** Run `pm2 logs openclaw-gw --lines 50`.

**Bot not responding?** Verify bot token and user ID in `%USERPROFILE%\.openclaw\openclaw.json` → `channels.telegram`.

**Node.js fails via winget?** Download manually from https://nodejs.org, then re-run installer.

---

## Version

v1.0 — May 2026

## Author

firyomaefx
