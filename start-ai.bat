@echo off
echo AI Services Starting...

REM Docker Desktopが起動するまで待機
timeout /t 30 /nobreak > nul

REM Docker Composeでサービスを起動
cd /d "%USERPROFILE%\Desktop\ai-setup"
docker compose up -d

echo All services started!
echo Access OpenWebUI at http://localhost:3000
pause