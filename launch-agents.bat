@echo off
REM LAUNCH ALL AGENTS IN SEPARATE TERMINALS
REM This batch file starts all three agents in new terminal windows

setlocal enabledelayedexpansion

set REPO_PATH=C:\Users\hp\Desktop\projekty_vs_code_porzadek\rojagentow
set PYTHON_PATH=python

echo.
echo ════════════════════════════════════════════════════════════
echo          LAUNCHING AUTONOMOUS AGENT FLEET
echo ════════════════════════════════════════════════════════════
echo.

REM Check if agents are already running
tasklist /FI "WINDOWTITLE eq *ALPHA*" 2>NUL | find /I /N "python.exe">NUL
if "%ERRORLEVEL%"=="0" (
    echo ⚠ WARNING: Agents may already be running!
    echo Check your task manager and close existing agent windows first.
    echo.
)

echo Launching ALPHA Agent (Deep Mathematician)...
start "AGENT ALPHA - Deep Mathematician" cmd /k "cd /d %REPO_PATH% && python agents\alpha\agent-alpha.py"

timeout /t 2 /nobreak

echo Launching BETA Agent (Creative Problem Solver)...
start "AGENT BETA - Creative Problem Solver" cmd /k "cd /d %REPO_PATH% && python agents\beta\agent-beta.py"

timeout /t 2 /nobreak

echo Launching GAMMA Agent (Visionary Synthesizer)...
start "AGENT GAMMA - Visionary Synthesizer" cmd /k "cd /d %REPO_PATH% && python agents\gamma\agent-gamma.py"

timeout /t 2 /nobreak

echo.
echo ════════════════════════════════════════════════════════════
echo ✓ All agents launched! Check your taskbar for new windows.
echo ════════════════════════════════════════════════════════════
echo.
echo Agent windows will:
echo  • Display colored output logs
echo  • Poll GitHub every 5 seconds
echo  • Execute copilot -i commands
echo  • Continue running until you close the window
echo.
echo To send tasks/messages, run: python master_control.py
echo.

pause
