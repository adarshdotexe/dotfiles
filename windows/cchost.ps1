<#
.SYNOPSIS
    `cchost` — open a Windows Terminal tab connected to a remote host's tmux
    session via mosh + sesh.

.DESCRIPTION
    cchost <host> <session>   — direct: open a tab into <session> on <host>
    cchost <host>             — pick a session interactively
    cchost                    — pick a host AND a session

    Each tab runs:
        wsl bash -lc "LC_ALL=C.UTF-8 LANG=C.UTF-8 mosh HOST -- sesh connect SESSION"

    sesh creates/attaches a tmux session per its config — falls back to a tmux
    session named SESSION if it's not in the sesh.toml.

    Source from $PROFILE to make it always available:
        . $HOME\repos\dotfiles\windows\cchost.ps1
#>

function Get-CchostHosts {
    $cfg = "$env:USERPROFILE\.ssh\config"
    if (-not (Test-Path $cfg)) { return @() }
    $hosts = New-Object System.Collections.Generic.List[string]
    foreach ($line in Get-Content $cfg) {
        $m = [regex]::Match($line, '^\s*Host\s+(.+?)\s*$', 'IgnoreCase')
        if (-not $m.Success) { continue }
        foreach ($n in ($m.Groups[1].Value -split '\s+')) {
            if ($n -and ($n -notmatch '[*?]')) { $hosts.Add($n) }
        }
    }
    $hosts | Sort-Object -Unique
}

function Get-CchostSessions {
    # Parse sesh.toml (same content on every host via dotfiles repo).
    $toml = "$env:USERPROFILE\repos\dotfiles\sesh\.config\sesh\sesh.toml"
    if (-not (Test-Path $toml)) { return @() }
    $names = New-Object System.Collections.Generic.List[string]
    foreach ($line in Get-Content $toml) {
        $m = [regex]::Match($line, '^\s*name\s*=\s*"([^"]+)"')
        if ($m.Success) { $names.Add($m.Groups[1].Value) }
    }
    $names | Sort-Object -Unique
}

function Select-FromList {
    param([string[]] $Items, [string] $Prompt)
    if (-not $Items -or $Items.Count -eq 0) { return $null }
    for ($i = 0; $i -lt $Items.Count; $i++) {
        Write-Host ("  [{0,2}] {1}" -f ($i + 1), $Items[$i])
    }
    $choice = Read-Host "$Prompt"
    if (-not $choice) { return $null }
    if ($choice -match '^\d+$') {
        $idx = [int]$choice - 1
        if ($idx -ge 0 -and $idx -lt $Items.Count) { return $Items[$idx] }
    }
    # Allow typing the name directly (substring match).
    $hits = $Items | Where-Object { $_ -like "*$choice*" }
    if ($hits.Count -eq 1) { return $hits[0] }
    Write-Warning "No unique match for '$choice'"
    return $null
}

function cchost {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)] [string] $HostName,
        [Parameter(Position = 1)] [string] $Session
    )

    if (-not $HostName) {
        $hosts = Get-CchostHosts
        if (-not $hosts) { Write-Error "No usable Host entries in ~/.ssh/config"; return }
        Write-Host "Hosts:" -ForegroundColor Cyan
        $HostName = Select-FromList -Items $hosts -Prompt 'host> '
        if (-not $HostName) { return }
    }

    if (-not $Session) {
        $sessions = @('main') + (Get-CchostSessions | Where-Object { $_ -ne 'main' })
        Write-Host "Sessions on ${HostName}:" -ForegroundColor Cyan
        $Session = Select-FromList -Items $sessions -Prompt "session> "
        if (-not $Session) { return }
    }

    # Escape single quotes inside session name for bash single-quoted arg.
    $seshArg   = $Session -replace "'", "'\''"
    $remoteCmd = "LC_ALL=C.UTF-8 LANG=C.UTF-8 mosh $HostName -- sesh connect '$seshArg'"

    Write-Host "→ ${HostName}: ${Session}" -ForegroundColor Green
    & wt.exe -w 0 new-tab --title "${HostName}:${Session}" `
        wsl.exe --cd '~' -- bash -lc $remoteCmd
}

# Convenience alias: ssh-from-shell hostname completion.
Set-Alias -Name ch -Value cchost
