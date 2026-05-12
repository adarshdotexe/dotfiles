# Standalone entry point so `tt.cmd` (from cmd.exe) and `pwsh tt-cli.ps1`
# (any non-loaded session) can drive the same logic that lives in tt.ps1.
. "$PSScriptRoot\tt.ps1"
tt @args
