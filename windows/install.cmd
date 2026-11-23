@echo off
rem claude-env Windows installer wrapper (bypasses the PowerShell execution policy for this run only)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
