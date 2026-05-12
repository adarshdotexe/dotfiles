@echo off
rem dotfiles: cmd.exe wrapper for tt (calls PowerShell, sources tt.ps1, runs tt).
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0tt-cli.ps1" %*
