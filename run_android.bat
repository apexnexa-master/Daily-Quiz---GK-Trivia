@echo off
REM Delegates to run_android.ps1 so Android device id is detected (Flutter has no -d android).
cd /d "%~dp0"
set "PUB_CACHE=D:\flutter-pub-cache"
set "TMP=D:\gradle-tmp"
set "TEMP=D:\gradle-tmp"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_android.ps1"
