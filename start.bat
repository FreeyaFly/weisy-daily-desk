@echo off
rem Weisy launcher (Windows): start the local server if it is not running, then open the page.
rem The server stops by itself a few seconds after the last Weisy window is closed.
cd /d "%~dp0"
set PORT=8780

curl.exe -s http://127.0.0.1:%PORT%/api/ping | find "weisy" >nul
if not errorlevel 1 goto open

where pythonw >nul 2>&1
if errorlevel 1 (
  echo Python 3 was not found. Install it from https://www.python.org and try again.
  pause
  exit /b 1
)
call :setup
python "%~dp0server.py" --check >"%TEMP%\weisy-check.txt" 2>&1
if errorlevel 1 (
  echo Weisy cannot start:
  echo.
  type "%TEMP%\weisy-check.txt"
  echo.
  pause
  exit /b 1
)
python tools\build.py >nul
start "" pythonw "%~dp0server.py" --port %PORT%

for /l %%i in (1,1,20) do (
  curl.exe -s -o nul http://127.0.0.1:%PORT%/api/ping && goto open
  timeout /t 1 /nobreak >nul
)
echo Weisy did not start.
python "%~dp0server.py" --check
echo.
echo If the line above says "Data folder", run "python server.py" in this folder to see the error.
pause
exit /b 1

:open
if "%WEISY_NO_WINDOW%"=="1" exit /b 0
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe" >nul 2>&1
if not errorlevel 1 (
  start "" msedge --app=http://127.0.0.1:%PORT%/
) else (
  start "" http://127.0.0.1:%PORT%/
)
exit /b 0

rem First-run setup (data folder and desktop shortcut): tools\setup.ps1 asks once, in a small dialog, BEFORE the server
rem starts so that a chosen data folder is used from the start. PowerShell is slow to start, so it is only called
rem when the answer is still missing or the program folder has moved (see setup.ps1).
:setup
if "%WEISY_NO_WINDOW%"=="1" exit /b 0
set "WEISY_DIR=%~dp0"
set "HERE=%~dp0"
set "HERE=%HERE:~0,-1%"
set "ANS="
if exist "%APPDATA%\Weisy-Data\desktop-shortcut.txt" set /p ANS=<"%APPDATA%\Weisy-Data\desktop-shortcut.txt"
if /i "%ANS%"=="no" exit /b 0
if /i "%ANS%"=="%HERE%" exit /b 0
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\setup.ps1" >nul 2>&1
exit /b 0
