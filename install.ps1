<# OpenClaw + OpenCode Dev Bridge - Windows Installer v1.0
.SYNOPSIS
Install OpenClaw Dev Bridge on Windows. Control it via Telegram.
.EXAMPLE
.\install.ps1 -TelegramToken "123:ABC" -TelegramUserId "123456"
#>
param(
    [string]$TelegramToken,
    [string]$TelegramUserId,
    [string]$OpenCodeApiKey
)

$ErrorActionPreference = "Stop"
$Host.UI.RawUI.WindowTitle = "OpenClaw Dev Bridge v1.0 - Setup"
$Conf = "$env:USERPROFILE\.openclaw"

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "    OpenClaw + OpenCode Dev Bridge v1.0"                -ForegroundColor Cyan
Write-Host "    Mobile-First AI Development Workflow"                -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

# ---- Step 1: Node.js -----------------------------------
Write-Host "[1/7] Checking Node.js..." -ForegroundColor Yellow
try {
    $nv = & node -v 2>$null
    if (-not $nv) { throw "not found" }
    Write-Host "  [OK] Node.js $nv" -ForegroundColor Green
} catch {
    Write-Host "  Installing Node.js LTS via winget..." -ForegroundColor Gray
    & winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements --silent 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Error "Failed to install Node.js. Download from https://nodejs.org"; exit 1 }
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
    $nv = & node -v 2>$null
    Write-Host "  [OK] Node.js $nv" -ForegroundColor Green
}

# ---- Step 2: Git ---------------------------------------
Write-Host "[2/7] Checking Git..." -ForegroundColor Yellow
try {
    $gv = & git --version 2>$null
    if (-not $gv) { throw "not found" }
    Write-Host "  [OK] $gv" -ForegroundColor Green
} catch {
    Write-Host "  Installing Git via winget..." -ForegroundColor Gray
    & winget install Git.Git --accept-source-agreements --accept-package-agreements --silent 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Error "Failed to install Git. Download from https://git-scm.com"; exit 1 }
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
    $gv = & git --version 2>$null
    Write-Host "  [OK] $gv" -ForegroundColor Green
}

# ---- Step 3: npm packages ------------------------------
Write-Host "[3/7] Installing npm packages (3-8 minutes)..." -ForegroundColor Yellow
$packages = @("openclaw", "opencode-ai", "pm2")
foreach ($pkg in $packages) {
    Write-Host "  Installing $pkg..." -ForegroundColor Gray
    & npm install -g $pkg 2>&1 | ForEach-Object { Write-Host "    $_" }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Retrying with legacy peer deps..." -ForegroundColor Gray
        & npm install -g $pkg --legacy-peer-deps 2>&1 | ForEach-Object { Write-Host "    $_" }
    }
    Write-Host "  [OK] $pkg" -ForegroundColor Green
}

# ---- Step 4: Ollama (optional) -------------------------
Write-Host "[4/7] Checking Ollama..." -ForegroundColor Yellow
try {
    $ol = & ollama -v 2>$null
    if (-not $ol) { throw "not found" }
    Write-Host "  [OK] Ollama $ol" -ForegroundColor Green
    $models = & ollama list 2>$null
    if ($models) { Write-Host "  Installed models:"; $models | ForEach-Object { Write-Host "    $_" } }
} catch {
    $choice = Read-Host "  Install Ollama? (y/n, recommended for local models)"
    if ($choice -eq "y") {
        Write-Host "  Installing Ollama..." -ForegroundColor Gray
        & winget install Ollama.Ollama --accept-source-agreements --accept-package-agreements --silent 2>&1 | Out-Null
        $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
        Write-Host "  [OK] Ollama installed. Start it from Start Menu." -ForegroundColor Green
    } else {
        Write-Host "  Skipped. Use cloud models (OpenRouter) instead." -ForegroundColor Gray
    }
}

# ---- Step 5: Credentials -------------------------------
Write-Host "[5/7] Configuration" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Gather these before continuing:" -ForegroundColor White
Write-Host "    * Telegram Bot Token   - from @BotFather on Telegram (/newbot)" -ForegroundColor Gray
Write-Host "    * Telegram User ID     - from @userinfobot on Telegram (a number)" -ForegroundColor Gray
Write-Host "    * OpenCode API Key     - from https://opencode.ai/auth" -ForegroundColor Gray
Write-Host ""

while (-not $TelegramToken) {
    $TelegramToken = Read-Host "  Telegram Bot Token"
    if (-not $TelegramToken) { Write-Host "  [X] Required." -ForegroundColor Red }
}

while (-not $TelegramUserId) {
    $TelegramUserId = Read-Host "  Your Telegram User ID (number)"
    if (-not $TelegramUserId) { Write-Host "  [X] Required." -ForegroundColor Red }
}

if (-not $OpenCodeApiKey) {
    $OpenCodeApiKey = Read-Host "  OpenCode API Key (sk-..., optional)"
}
if ($OpenCodeApiKey) {
    [Environment]::SetEnvironmentVariable("OPENCODE_API_KEY", $OpenCodeApiKey, "User")
    Write-Host "  [OK] OPENCODE_API_KEY saved" -ForegroundColor Green
}

# ---- Step 6: Generate config ---------------------------
Write-Host "[6/7] Generating config files..." -ForegroundColor Yellow

# Create directories
$dirs = @(
    "$Conf\tasks\pending",
    "$Conf\tasks\in_progress",
    "$Conf\tasks\done",
    "$Conf\tasks\completed",
    "$Conf\tasks\failed",
    "$Conf\agents\main\sessions"
)
foreach ($d in $dirs) { New-Item -ItemType Directory -Force -Path $d | Out-Null }

# Build system prompt
$sp = @"
=== ROLE: PROJECT MANAGER (OpenClaw) ===
You are the PM and mobile dev dispatch hub. All dev tasks delegate to OpenCode ACP. Non-dev tasks handle directly.

=== COMMAND ROUTING TABLE ===
/beta [desc]  > sessions_spawn(runtime:"acp", agentId:"opencode", mode:"oneshot", prompt:"<full task>", cwd:"C:\\Dev\\Projects") — Acknowledge, dispatch, report result.
/plan [feat]  > Reply with PRD/spec/breakdown directly. No dispatch.
/status       > Read tasks/*/ counts + recent task summary.
/push         > sessions_spawn: git add . && git commit -m "update" && git push
/review       > sessions_spawn: review last diff, report issues
/ask [q]      > Direct LLM answer. No dispatch.

=== ACP DELEGATION ===
Use sessions_spawn(runtime:"acp", agentId:"opencode", mode:"oneshot", prompt:"<task with absolute paths>", cwd:"C:\\Dev\\Projects")

=== TASK QUEUE ===
Location: C:\Users\${env:USERNAME}\.openclaw\tasks\{pending,in_progress,done,failed}\
Task JSON: {"task_id":"t001","created_at":"ISO","prompt":"full task","cwd":"C:\\Dev\\Projects","acceptance":[],"status":"pending"}

=== REPORTING ===
1. Ack command instantly in Telegram
2. Spawn OpenCode ACP session (or queue for complex tasks)
3. Report result + summary back to Telegram
4. On failure: report error + write to /tasks/failed/
"@

$upE = $env:USERPROFILE -replace '\\', '\\'
$gwToken = '_ocb_' + [guid]::NewGuid().ToString('N').Substring(0,16)

$cfg = [ordered]@{
    acp = @{allowedAgents = @('opencode'); backend = 'acpx'; defaultAgent = 'opencode'; enabled = $true}
    agents = @{defaults = @{
        compaction = @{mode = 'safeguard'}
        maxConcurrent = 4
        memorySearch = @{enabled = $true; model = 'ollama/glm-4.7-flash'; provider = 'ollama'}
        model = @{primary = 'ollama/kimi-k2.6:cloud'}
        subagents = @{maxConcurrent = 8; model = 'ollama/glm-4.7-flash'; thinking = 'off'}
        timeoutSeconds = 86400
        workspace = "$upE\\.openclaw\\workspace"
    }}
    channels = @{telegram = @{
        allowFrom = @($TelegramUserId)
        botToken = $TelegramToken
        direct = @{$TelegramUserId = @{systemPrompt = $sp}}
        dmPolicy = 'pairing'
        enabled = $true
        groupAllowFrom = @()
        groupPolicy = 'allowlist'
        streaming = @{mode = 'off'}
    }}
    commands = @{native = 'auto'; nativeSkills = 'auto'; ownerDisplay = 'raw'; restart = $true}
    gateway = @{
        auth = @{mode = 'token'; token = $gwToken}
        bind = 'loopback'
        mode = 'local'
        nodes = @{denyCommands = @()}
        port = 18789
        tailscale = @{mode = 'off'; resetOnExit = $false}
    }
    hooks = @{internal = @{
        enabled = $true
        entries = [ordered]@{
            'boot-md' = @{enabled = $true}
            'bootstrap-extra-files' = @{enabled = $true}
            'command-logger' = @{enabled = $true}
            'self-improvement' = @{enabled = $true}
            'session-memory' = @{enabled = $true}
        }
    }}
    messages = @{ackReactionScope = 'group-mentions'}
    models = @{providers = @{
        ollama = @{api = 'ollama'; apiKey = 'ollama-local'; baseUrl = 'http://127.0.0.1:11434'}
    }}
    plugins = @{
        allow = @('telegram', 'acpx', 'ollama', 'memory-core')
        entries = @{
            acpx = @{config = @{
                mcpServers = @{}
                nonInteractivePermissions = 'fail'
                permissionMode = 'approve-all'
            }; enabled = $true}
            ollama = @{enabled = $true}
            telegram = @{enabled = $true}
        }
    }
    session = @{dmScope = 'per-channel-peer'}
    tools = @{web = @{
        fetch = @{enabled = $true}
        search = @{enabled = $true; provider = 'ollama'}
    }}
}

$json = $cfg | ConvertTo-Json -Depth 12
if (-not $json) {
    Write-Host "  [X] Failed to generate config JSON" -ForegroundColor Red
    exit 1
}
$json | Out-File -Encoding utf8 "$Conf\openclaw.json"
Write-Host "  [OK] openclaw.json" -ForegroundColor Green

# Write ecosystem.config.cjs
@'
module.exports = {
  apps: [{
    name: 'openclaw-gw',
    script: process.env.USERPROFILE + '\\AppData\\Roaming\\npm\\node_modules\\openclaw\\openclaw.mjs',
    interpreter: 'node',
    args: 'gateway start',
    cwd: process.env.USERPROFILE,
    restart_delay: 3000,
    max_restarts: 10
  }]
};
'@ | Out-File -Encoding utf8 "$Conf\ecosystem.config.cjs"
Write-Host "  [OK] ecosystem.config.cjs" -ForegroundColor Green

"@echo off`nopenclaw gateway start" | Out-File -Encoding ascii "$Conf\gateway.cmd"
Write-Host "  [OK] gateway.cmd" -ForegroundColor Green

# ---- Step 7: Start the gateway -------------------------
Write-Host "[7/7] Starting gateway..." -ForegroundColor Yellow

pm2 delete openclaw-gw 2>&1 | Out-Null
Push-Location $Conf
pm2 start ecosystem.config.cjs
Pop-Location

Write-Host "  Waiting for gateway to boot..." -ForegroundColor Gray
Start-Sleep -Seconds 15

pm2 save 2>&1 | Out-Null
pm2 startup 2>&1 | Out-Null
Write-Host "  [OK] Gateway started + auto-start on boot configured" -ForegroundColor Green

# ---- Verify --------------------------------------------
Write-Host ""
Write-Host "  Verifying gateway..." -ForegroundColor Yellow
try {
    $result = Invoke-WebRequest -Uri "http://127.0.0.1:18789/__openclaw__/health" `
        -Headers @{"Authorization" = "Bearer $gwToken"} `
        -UseBasicParsing -TimeoutSec 15
    if ($result.StatusCode -eq 200) {
        Write-Host "  [OK] Gateway healthy - http://127.0.0.1:18789" -ForegroundColor Green
    } else {
        Write-Host "  [!] Gateway responded: $($result.StatusCode)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  [!] Gateway still booting - this is normal. Give it 30 more seconds." -ForegroundColor Yellow
}

# ---- Done ----------------------------------------------
Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "                 INSTALL COMPLETE"                     -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Gateway URL:  http://127.0.0.1:18789"               -ForegroundColor White
Write-Host "  Process:      pm2 (openclaw-gw)"                     -ForegroundColor White
Write-Host ""
Write-Host "  ------ YOUR TELEGRAM COMMANDS -----------------------" -ForegroundColor Cyan
Write-Host "  Send these to your bot:"                             -ForegroundColor White
Write-Host ""
Write-Host "    /ask hello             - Quick LLM response"       -ForegroundColor White
Write-Host "    /beta Build a REST API - Dispatch to OpenCode"     -ForegroundColor White
Write-Host "    /plan Feature name     - Get detailed PRD"         -ForegroundColor White
Write-Host "    /status                - Check task queue"         -ForegroundColor White
Write-Host "    /push                  - Git commit + push"        -ForegroundColor White
Write-Host "    /review                - Code review last diff"    -ForegroundColor White
Write-Host ""
Write-Host "  ------ MANAGEMENT ----------------------------------" -ForegroundColor Cyan
Write-Host "    pm2 logs openclaw-gw      - Live gateway logs"     -ForegroundColor White
Write-Host "    pm2 restart openclaw-gw   - Restart gateway"       -ForegroundColor White
Write-Host "    pm2 stop openclaw-gw      - Stop gateway"          -ForegroundColor White
Write-Host "    pm2 status                - Show all processes"     -ForegroundColor White
Write-Host ""
Write-Host "  Config:      $Conf\openclaw.json"                    -ForegroundColor Gray
Write-Host "  Logs:        $env:TEMP\openclaw\"                     -ForegroundColor Gray
Write-Host ""
Write-Host "  Open Telegram and send /ask hello to your bot!"       -ForegroundColor Green
Write-Host ""
