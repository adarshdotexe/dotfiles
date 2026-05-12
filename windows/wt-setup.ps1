<#
.SYNOPSIS
    Add a Windows Terminal profile + keybinding for every Host in your SSH config.

.DESCRIPTION
    Each generated profile launches:
        wsl.exe --cd ~ -- mosh HOST -- tmux new -A -s main
    so it survives sleep/wifi-roam (mosh) and preserves session state (tmux).
    Inside tmux, Prefix + K opens the sesh picker to switch project sessions.

    Profiles are matched by name (idempotent). Re-running updates commandline
    in place rather than duplicating.

.NOTES
    Backup of settings.json is written next to it as settings.json.bak.<unix-ts>.
    To revert: copy that backup back over settings.json and restart Windows Terminal.

.PARAMETER SshConfig
    Path to the SSH config to parse. Defaults to $HOME\.ssh\config.

.PARAMETER WtSettings
    Path to Windows Terminal settings.json. Auto-detected for stable WT build.

.PARAMETER TmuxSession
    Name of the tmux session each profile attaches to. Default: main.

.PARAMETER Bindings
    If set, also add ctrl+alt+1..9 keybindings for the first 9 hosts.
#>

[CmdletBinding()]
param(
    [string] $SshConfig   = "$env:USERPROFILE\.ssh\config",
    [string] $WtSettings  = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    [string] $TmuxSession = 'main',
    [switch] $Bindings    = $true
)

$ErrorActionPreference = 'Stop'

function Get-DeterministicGuid {
    param([string] $Name)
    $md5 = [System.Security.Cryptography.MD5]::Create()
    try {
        $bytes = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes("wt-remote-$Name"))
        # Stamp version (5) and variant bits to make it a valid UUIDv5-ish.
        $bytes[6] = ($bytes[6] -band 0x0F) -bor 0x50
        $bytes[8] = ($bytes[8] -band 0x3F) -bor 0x80
        return ([System.Guid]::new($bytes)).Guid
    } finally { $md5.Dispose() }
}

function Get-SshHosts {
    param([string] $Path)
    if (-not (Test-Path $Path)) { throw "ssh config not found: $Path" }
    $hosts = @()
    foreach ($line in Get-Content $Path) {
        $m = [regex]::Match($line, '^\s*Host\s+(.+?)\s*$', 'IgnoreCase')
        if (-not $m.Success) { continue }
        foreach ($name in ($m.Groups[1].Value -split '\s+')) {
            if ($name -eq '*' -or $name -match '[*?]') { continue }
            if ($name -match '^\s*$') { continue }
            $hosts += $name
        }
    }
    $hosts | Select-Object -Unique
}

function New-ProfileEntry {
    param([string] $HostName, [string] $Session)
    # Use `bash -lc` so ~/.profile runs first — that's what initialises the
    # wsl-ssh-agent bridge so mosh's underlying ssh can authenticate via key.
    # LC_ALL=C.UTF-8 LANG=C.UTF-8 — WSL's /etc/default/locale forces en_US.UTF-8
    # which Rocky 8 / BAN doesn't have generated. Force a locale the remote has.
    $inner  = "export TT_HOST_ALIAS=$HostName; exec tmux new -A -s $Session"
    # MOSH_TITLE_NOPREFIX=1 disables mosh-client's hard-coded "[mosh] " title prefix.
    $remote = "MOSH_TITLE_NOPREFIX=1 LC_ALL=C.UTF-8 LANG=C.UTF-8 mosh $HostName -- bash -c `"$inner`""
    [ordered] @{
        guid        = "{$(Get-DeterministicGuid $HostName)}"
        name        = $HostName
        tabTitle    = $HostName
        commandline = "wsl.exe --cd ~ -- bash -lc `"$remote`""
        hidden      = $false
        # Let mosh/tmux dynamically set "alias:path" — the inner tmux config
        # uses TT_HOST_ALIAS so the title reads as the ssh-config alias rather
        # than the remote FQDN.
    }
}

if (-not (Test-Path $WtSettings)) {
    throw "Windows Terminal settings.json not found at: $WtSettings"
}

$hosts = Get-SshHosts -Path $SshConfig
if (-not $hosts) { throw "No usable Host entries in $SshConfig" }
Write-Host "Found hosts:" -ForegroundColor Cyan
$hosts | ForEach-Object { Write-Host "  - $_" }

# Backup
$ts  = [DateTimeOffset]::Now.ToUnixTimeSeconds()
$bak = "$WtSettings.bak.$ts"
Copy-Item $WtSettings $bak
Write-Host "Backed up settings.json -> $bak" -ForegroundColor Yellow

$settings = Get-Content $WtSettings -Raw | ConvertFrom-Json

# Ensure structure
if (-not $settings.profiles)      { $settings | Add-Member -NotePropertyName profiles      -NotePropertyValue ([PSCustomObject]@{ list = @() }) }
if (-not $settings.profiles.list) { $settings.profiles | Add-Member -NotePropertyName list -NotePropertyValue @() -Force }
if (-not $settings.keybindings)   { $settings | Add-Member -NotePropertyName keybindings   -NotePropertyValue @() }

$existing = @{}
foreach ($p in $settings.profiles.list) { if ($p.name) { $existing[$p.name] = $p } }

$added = 0; $updated = 0
$newList = @($settings.profiles.list)
foreach ($h in $hosts) {
    $entry = New-ProfileEntry -HostName $h -Session $TmuxSession
    if ($existing.ContainsKey($h)) {
        $existing[$h].commandline = $entry.commandline
        $existing[$h].guid        = $entry.guid
        if (-not $existing[$h].tabTitle) {
            $existing[$h] | Add-Member tabTitle $entry.tabTitle -Force
        }
        # Drop any old suppressApplicationTitle — we let mosh/tmux update the
        # title dynamically now (so it can show "alias:path").
        $existing[$h].PSObject.Properties.Remove('suppressApplicationTitle')
        $updated++
    } else {
        $newList += [PSCustomObject] $entry
        $added++
    }
}
$settings.profiles.list = $newList

if ($Bindings) {
    $keyList = @($settings.keybindings)
    $i = 0
    foreach ($h in $hosts) {
        if ($i -ge 9) { break }
        $i++
        $keys = "ctrl+alt+$i"
        # Drop any existing binding on the same keys, then add fresh.
        $keyList = $keyList | Where-Object { $_.keys -ne $keys }
        $keyList += [PSCustomObject] @{
            command = [PSCustomObject] @{ action = 'newTab'; profile = $h }
            keys    = $keys
        }
    }
    $settings.keybindings = $keyList
}

$json = $settings | ConvertTo-Json -Depth 64
[System.IO.File]::WriteAllText($WtSettings, $json, (New-Object System.Text.UTF8Encoding $false))

Write-Host ""
Write-Host "Done. Added $added new profile(s), updated $updated existing." -ForegroundColor Green
if ($Bindings) {
    Write-Host "Keybindings: ctrl+alt+1..$([math]::Min($hosts.Count, 9)) -> new tab for first $([math]::Min($hosts.Count, 9)) host(s)." -ForegroundColor Green
}
Write-Host "Open or restart Windows Terminal to pick them up."
Write-Host ""
Write-Host "Try:  Ctrl+Alt+1   (or the dropdown -> $($hosts[0]))"
