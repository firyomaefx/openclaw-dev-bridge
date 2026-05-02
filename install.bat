@echo off
setlocal enabledelayedexpansion
title OpenClaw Dev Bridge v1.0 - Setup
color 0F

echo.
echo ======================================================
echo     OpenClaw + OpenCode Dev Bridge v1.0
echo     Mobile-First AI Development Workflow
echo ======================================================
echo.

cd /d "%USERPROFILE%"

echo This script will install:
echo    - Node.js (if missing)
echo    - Git (if missing)
echo    - openclaw, opencode-ai, pm2 (npm packages)
echo    - Ollama (optional)
echo    - OpenClaw Dev Bridge configuration
echo.
echo It needs internet access and Administrator rights.
echo.
pause

:: ---- helpers --------------------------------------------
:refresh_path
for /f "tokens=2*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH 2^>nul') do set "MP=%%b"
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v PATH 2^>nul') do set "UP=%%b"
set "PATH=%MP%;%UP%;%PATH%"
goto :eof

:: ---- [1/8] Node.js -------------------------------------
echo.
echo [1/8] Checking Node.js...
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo   Installing Node.js via winget...
    winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
    call :refresh_path
)
for /f "tokens=*" %%i in ('node -v 2^>nul') do set "NODE_VER=%%i"
echo   [OK] Node.js %NODE_VER%

:: ---- [2/8] Git -----------------------------------------
echo.
echo [2/8] Checking Git...
where git >nul 2>&1
if %errorlevel% neq 0 (
    echo   Installing Git via winget...
    winget install Git.Git --accept-source-agreements --accept-package-agreements
    call :refresh_path
)
for /f "tokens=*" %%i in ('git --version 2^>nul') do set "GIT_VER=%%i"
echo   [OK] %GIT_VER%

:: ---- [3/8] npm -----------------------------------------
echo.
echo [3/8] Checking npm...
for /f "tokens=*" %%i in ('npm -v 2^>nul') do set "NPM_VER=%%i"
echo   [OK] npm v%NPM_VER%

:: ---- [4/8] Install Node packages -----------------------
echo.
echo [4/8] Installing npm packages...
echo   This downloads ~400 MB and may take 3-8 minutes.
echo.

echo   [1/3] openclaw (gateway)...
call npm install -g openclaw
if errorlevel 1 (
    echo   [!] Retrying with legacy peer deps...
    call npm install -g openclaw --legacy-peer-deps
)
echo   [OK] openclaw

echo.
echo   [2/3] opencode-ai (agent)...
call npm install -g opencode-ai
if errorlevel 1 (
    echo   [!] Retrying with legacy peer deps...
    call npm install -g opencode-ai --legacy-peer-deps
)
echo   [OK] opencode-ai

echo.
echo   [3/3] pm2 (process manager)...
call npm install -g pm2
if errorlevel 1 (
    echo   [!] Retrying with legacy peer deps...
    call npm install -g pm2 --legacy-peer-deps
)
echo   [OK] pm2

:: ---- [5/8] Ollama --------------------------------------
echo.
echo [5/8] Checking Ollama (local AI runtime)...
where ollama >nul 2>&1
if %errorlevel% neq 0 (
    echo   Ollama is NOT installed.
    echo.
    echo   Install Ollama? (Recommended - allows offline AI via local models)
    echo   Requires ~6 GB free disk space for one model.
    echo.
    choice /c YN /m "   Choose Y or N"
    if errorlevel 2 goto :no_ollama
    echo   Installing Ollama...
    winget install Ollama.Ollama --accept-source-agreements --accept-package-agreements
    call :refresh_path
    echo   Ollama installed. Start it from the Start Menu, then run models.
    goto :ollama_done
    :no_ollama
    echo   Ollama skipped. You can use cloud models (OpenRouter) instead.
) else (
    for /f "tokens=*" %%i in ('ollama -v 2^>nul') do set "OL_VER=%%i"
    echo   [OK] Ollama !OL_VER!
    echo   Checking installed models...
    :: Don't let ollama list hang if the service is down
    start /b "" ollama list > "%TEMP%\ollama_list.txt" 2>&1
    ping -n 4 127.0.0.1 >nul
    type "%TEMP%\ollama_list.txt" 2>nul
    del "%TEMP%\ollama_list.txt" >nul 2>&1
)
:ollama_done

:: ---- [6/8] Collect credentials -------------------------
echo.
echo [6/8] Configuration - enter your credentials
echo   (Get these BEFORE continuing if you haven't yet)
echo.
echo   * Telegram Bot Token: from @BotFather on Telegram (/newbot)
echo   * Telegram User ID:   from @userinfobot on Telegram (it's a number)
echo   * OpenCode API Key:   from https://opencode.ai/auth
echo.

:ask_token
set "TG_TOKEN="
set /p "TG_TOKEN=   Telegram Bot Token: "
if "%TG_TOKEN%"=="" (
    echo   [X] Required. This is how the bridge talks to Telegram.
    goto :ask_token
)

:ask_uid
set "TG_UID="
set /p "TG_UID=   Your Telegram User ID (number): "
if "%TG_UID%"=="" (
    echo   [X] Required. The bridge only responds to this ID.
    goto :ask_uid
)

set "OC_KEY="
set /p "OC_KEY=   OpenCode API Key (sk-..., optional): "
if not "%OC_KEY%"=="" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "[Environment]::SetEnvironmentVariable('OPENCODE_API_KEY','%OC_KEY%','User')"
    echo   [OK] OPENCODE_API_KEY saved
) else (
    echo   [SKIP] Set later via Windows environment variables
)

:: ---- [7/8] Generate config -----------------------------
echo.
echo [7/8] Generating configuration files...

set "CONF=%USERPROFILE%\.openclaw"
if not exist "%CONF%" mkdir "%CONF%"
mkdir "%CONF%\tasks\pending"        2>nul
mkdir "%CONF%\tasks\in_progress"   2>nul
mkdir "%CONF%\tasks\done"          2>nul
mkdir "%CONF%\tasks\completed"     2>nul
mkdir "%CONF%\tasks\failed"        2>nul
mkdir "%CONF%\agents\main\sessions" 2>nul

:: Write system prompt to a temp file (avoids cmd escaping issues)
(
echo === ROLE: PROJECT MANAGER ^(OpenClaw^) ===
echo You are the PM and mobile dev dispatch hub. All dev tasks delegate to OpenCode ACP. Non-dev tasks handle directly.
echo.
echo === COMMAND ROUTING TABLE ===
echo /beta [desc]  ^> sessions_spawn^(runtime:"acp", agentId:"opencode", mode:"oneshot", prompt:"^<full task^>", cwd:"C:\\Dev\\Projects"^) - Acknowledge, dispatch, report result.
echo /plan [feat]  ^> Reply with PRD/spec/breakdown directly. No dispatch.
echo /status       ^> Read tasks^*^/ counts + recent task summary.
echo /push         ^> sessions_spawn: git add . ^&^& git commit -m "update" ^&^& git push
echo /review       ^> sessions_spawn: review last diff, report issues
echo /ask [q]      ^> Direct LLM answer. No dispatch.
echo.
echo === ACP DELEGATION ===
echo Use sessions_spawn^(runtime:"acp", agentId:"opencode", mode:"oneshot", prompt:"^<task with absolute paths^>", cwd:"C:\\Dev\\Projects"^)
echo.
echo === TASK QUEUE ===
echo Location: C:\Users\%USERNAME%\.openclaw\tasks\{pending,in_progress,done,failed}\
echo Task JSON: {"task_id":"t001","created_at":"ISO","prompt":"full task","cwd":"C:\\Dev\\Projects","acceptance":[],"status":"pending"}
echo.
echo === REPORTING ===
echo 1. Ack command instantly in Telegram
echo 2. Spawn OpenCode ACP session ^(or queue for complex tasks^)
echo 3. Report result + summary back to Telegram
echo 4. On failure: report error + write to /tasks/failed/
) > "%CONF%\_sysprompt.txt"

:: Store user data in env vars (safe way to pass to PowerShell)
set "OCB_TK=%TG_TOKEN%"
set "OCB_UID=%TG_UID%"

echo   Generating openclaw.json...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$up=$env:USERPROFILE; $u=$env:USERNAME; $tk=$env:OCB_TK; $uid=$env:OCB_UID; "^
"$gwToken='_ocb_'+[guid]::NewGuid().ToString('N').Substring(0,16); "^
"$sp=((Get-Content (Join-Path $up '.openclaw\_sysprompt.txt') -Raw) -split '\r?\n' | ForEach-Object {$_.TrimEnd()}) -join '\n'; "^
"$upE=$up.Replace('\','\\'); "^
"$cfg=@{"^
"  acp=@{allowedAgents=@('opencode');backend='acpx';defaultAgent='opencode';enabled=$true};"^
"  agents=@{defaults=@{"^
"    compaction=@{mode='safeguard'};maxConcurrent=4;"^
"    memorySearch=@{enabled=$true;model='ollama/glm-4.7-flash';provider='ollama'};"^
"    model=@{primary='ollama/kimi-k2.6:cloud'};"^
"    subagents=@{maxConcurrent=8;model='ollama/glm-4.7-flash';thinking='off'};"^
"    timeoutSeconds=86400;workspace=$upE\\.openclaw\\workspace"^
"  }};"^
"  channels=@{telegram=@{"^
"    allowFrom=@($uid);botToken=$tk;"^
"    direct=@{$uid=@{systemPrompt=$sp}};"^
"    dmPolicy='pairing';enabled=$true;groupAllowFrom=@();"^
"    groupPolicy='allowlist';streaming=@{mode='off'}"^
"  }};"^
"  commands=@{native='auto';nativeSkills='auto';ownerDisplay='raw';restart=$true};"^
"  gateway=@{auth=@{mode='token';token=$gwToken};bind='loopback';mode='local';"^
"    nodes=@{denyCommands=@()};port=18789;tailscale=@{mode='off';resetOnExit=$false}};"^
"  hooks=@{internal=@{enabled=$true;entries=@{"^
"    'boot-md'=@{enabled=$true};'bootstrap-extra-files'=@{enabled=$true};"^
"    'command-logger'=@{enabled=$true};'self-improvement'=@{enabled=$true};"^
"    'session-memory'=@{enabled=$true}}}};"^
"  messages=@{ackReactionScope='group-mentions'};"^
"  models=@{providers=@{ollama=@{api='ollama';apiKey='ollama-local';baseUrl='http://127.0.0.1:11434'}}};"^
"  plugins=@{allow=@('telegram','acpx','ollama','memory-core');entries=@{"^
"    acpx=@{config=@{mcpServers=@{};nonInteractivePermissions='fail';permissionMode='approve-all'};enabled=$true};"^
"    ollama=@{enabled=$true};telegram=@{enabled=$true}"^
"  }};"^
"  session=@{dmScope='per-channel-peer'};"^
"  tools=@{web=@{fetch=@{enabled=$true};search=@{enabled=$true;provider='ollama'}}}"^
"}; "^
"$json=$cfg|ConvertTo-Json -Depth 12; "^
"if ($json) {"^
"  $json|Out-File -Encoding utf8 (Join-Path $up '.openclaw\openclaw.json'); "^
"  Write-Host '  [OK] openclaw.json generated';"^
"} else { Write-Host '  [ERROR] Failed to generate config'; exit 1 }"

if %errorlevel% neq 0 (
    echo   [X] Config generation failed! Check the output above.
    pause
)

:: Clean temp file
del "%CONF%\_sysprompt.txt" >nul 2>&1

:: Write ecosystem.config.cjs
(
echo module.exports = {
echo   apps: [{
echo     name: 'openclaw-gw',
echo     script: process.env.USERPROFILE + '\\AppData\\Roaming\\npm\\node_modules\\openclaw\\openclaw.mjs',
echo     interpreter: 'node',
echo     args: 'gateway start',
echo     cwd: process.env.USERPROFILE,
echo     restart_delay: 3000,
echo     max_restarts: 10
echo   }]
echo };
) > "%CONF%\ecosystem.config.cjs"
echo   [OK] ecosystem.config.cjs

echo @echo off > "%CONF%\gateway.cmd"
echo openclaw gateway start >> "%CONF%\gateway.cmd"

:: ---- [8/8] Start the gateway ---------------------------
echo.
echo [8/8] Starting the gateway...

pm2 delete openclaw-gw >nul 2>&1
cd /d "%CONF%"
call pm2 start ecosystem.config.cjs
echo   Waiting for gateway to boot (15-30 seconds)...
timeout /t 15 >nul
call pm2 save >nul 2>&1
call pm2 startup >nul 2>&1
echo   [OK] Gateway started + auto-start on boot configured

:: ---- Verify --------------------------------------------
echo.
echo   Verifying gateway...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$cfg=Get-Content (Join-Path $env:USERPROFILE '.openclaw\openclaw.json') -Raw|ConvertFrom-Json; "^
"$token=$cfg.gateway.auth.token; "^
"try{"^
"  $r=Invoke-WebRequest -Uri 'http://127.0.0.1:18789/__openclaw__/health' -Headers @{'Authorization'='Bearer '+$token} -UseBasicParsing -TimeoutSec 10;"^
"  if($r.StatusCode -eq 200){Write-Host '  [OK] Gateway healthy - http://127.0.0.1:18789'}else{Write-Host '  [!] Gateway responded: '+$r.StatusCode}"^
"}catch{Write-Host '  [!] Gateway still booting - this is normal. Wait 30 more seconds.'}"

:: ---- Done ----------------------------------------------
echo.
echo ======================================================
echo                 INSTALL COMPLETE
echo ======================================================
echo.
echo   Gateway URL:  http://127.0.0.1:18789
echo   Process:      pm2 (openclaw-gw)
echo.
echo   ------ YOUR TELEGRAM COMMANDS -----------------------
echo   Send these to your bot on Telegram:
echo.
echo     /ask hello             - Quick LLM response
echo     /beta Build a REST API - Dispatch to OpenCode
echo     /plan Feature name     - Get detailed PRD
echo     /status                - Check task queue
echo     /push                  - Git commit + push
echo     /review                - Code review last diff
echo.
echo   ------ MANAGEMENT ----------------------------------
echo     pm2 logs openclaw-gw      - Live gateway logs
echo     pm2 restart openclaw-gw   - Restart gateway
echo     pm2 stop openclaw-gw      - Stop gateway
echo     pm2 status                - Show all processes
echo.
echo   Config:       %CONF%\openclaw.json
echo   Logs:         %TEMP%\openclaw\
echo.
echo   Open Telegram and send /ask hello to your bot!
echo.
pause
exit /b 0
