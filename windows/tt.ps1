<#
.SYNOPSIS
    tt - open a WezTerm mux workspace, ranked by frecency.

.DESCRIPTION
    Tracks every (host, session) pair launched in $env:USERPROFILE\.config\tt\db.tsv.
    A launch opens the matching WezTerm domain/workspace:

        WSL/main -> domain WSL, workspace WSL:main
        BAN/pia  -> domain BAN, workspace BAN:pia

    Remote hosts use WezTerm SSH multiplexing, so panes survive GUI disconnects
    without mosh or tmux.

.USAGE
    tt                  # fzf picker, highest-frecency first
    tt <query>          # fuzzy substring match against "HOST SESSION"
    tt -n HOST SESSION  # create/promote and launch
    tt -a HOST SESSION  # add/promote without launching
    tt -l               # list ranked entries
#>

$script:TtDbPath = Join-Path $env:USERPROFILE '.config\tt\db.tsv'

function _Tt-ReadDb {
    $dir = Split-Path $script:TtDbPath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory $dir -Force | Out-Null }
    if (-not (Test-Path $script:TtDbPath)) { return @{} }
    $db = @{}
    foreach ($line in Get-Content $script:TtDbPath) {
        if ($line -match '^([^\t]+)\t([^\t]+)\t([0-9.]+)\t(\d+)$') {
            $key = "$($matches[1])`t$($matches[2])"
            $db[$key] = [PSCustomObject]@{
                Host     = $matches[1]
                Session  = $matches[2]
                Rank     = [double] $matches[3]
                LastUsed = [int64]  $matches[4]
            }
        }
    }
    $db
}

function _Tt-WriteDb {
    param([hashtable] $Db)
    $lines = $Db.Values | ForEach-Object {
        '{0}`t{1}`t{2}`t{3}' -f $_.Host, $_.Session, $_.Rank, $_.LastUsed
    }
    $lines = $lines -replace '`t', "`t"
    Set-Content -Path $script:TtDbPath -Value $lines -Encoding utf8
}

function _Tt-Score {
    param([PSCustomObject] $E, [int64] $Now)
    if ($E.LastUsed -le 0) { return $E.Rank }
    $age = $Now - $E.LastUsed
    $factor = 0.25
    if     ($age -lt 3600)   { $factor = 4 }
    elseif ($age -lt 86400)  { $factor = 2 }
    elseif ($age -lt 604800) { $factor = 0.5 }
    return $E.Rank * $factor
}

function _Tt-Seed {
    param([hashtable] $Db)
    $cfg = "$env:USERPROFILE\.ssh\config"
    $hosts = @()

    if (Test-Path $cfg) {
        foreach ($line in Get-Content $cfg) {
            $m = [regex]::Match($line, '^\s*Host\s+(.+?)\s*$', 'IgnoreCase')
            if (-not $m.Success) { continue }
            foreach ($n in ($m.Groups[1].Value -split '\s+')) {
                if ($n -and ($n -notmatch '[*?]')) { $hosts += $n }
            }
        }
    }

    $hosts = @('WSL') + $hosts
    foreach ($h in $hosts) {
        $key = "${h}`tmain"
        if (-not $Db.ContainsKey($key)) {
            $Db[$key] = [PSCustomObject]@{
                Host     = $h
                Session  = 'main'
                Rank     = 0.0
                LastUsed = 0
            }
        }
    }

    $validHosts = @{}
    foreach ($h in $hosts) { $validHosts[$h] = $true }
    $toRemove = @()
    foreach ($k in $Db.Keys) {
        if (-not $validHosts.ContainsKey($Db[$k].Host)) { $toRemove += $k }
    }
    foreach ($k in $toRemove) { $Db.Remove($k) | Out-Null }
}

function _Tt-FindWezTerm {
    $cmd = Get-Command wezterm.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($candidate in @(
        "$env:ProgramFiles\WezTerm\wezterm.exe",
        "${env:ProgramFiles(x86)}\WezTerm\wezterm.exe",
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\wezterm.exe",
        "$env:USERPROFILE\scoop\apps\wezterm\current\wezterm.exe"
    )) {
        if ($candidate -and (Test-Path $candidate)) { return $candidate }
    }
    return $null
}

# Given the CLI binary (wezterm.exe), return its GUI sibling. wezterm.exe is a
# console-subsystem app, so Start-Process'ing it pops a command window that just
# streams wezterm's logs; wezterm-gui.exe is the windows-subsystem build and
# opens the GUI with no console. wezterm.exe is only needed for `cli`.
function _Tt-GuiBin {
    param([string] $Cli)
    if ($Cli) {
        $gui = Join-Path (Split-Path -Parent $Cli) 'wezterm-gui.exe'
        if (Test-Path $gui) { return $gui }
    }
    $cmd = Get-Command wezterm-gui.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function _Tt-NormalizeHost {
    param([string] $HostName)
    if ($HostName -ieq 'wsl') { return 'WSL' }
    return $HostName
}

function _Tt-RemoteHome {
    param([string] $HostName)
    switch -Exact ($HostName) {
        'H100'  { return '/root' }
        'GB100' { return '/root' }
        default { return '/home/advarshney' }
    }
}

function _Tt-WorkspaceExists {
    param([string] $WezTerm, [string] $Workspace)
    try {
        $json = & $WezTerm cli list --format json 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $json) { return $false }
        $items = $json | ConvertFrom-Json
        foreach ($item in @($items)) {
            if ($item.workspace -eq $Workspace) { return $true }
        }
    } catch {
        return $false
    }
    return $false
}

function _Tt-Launch {
    param([PSCustomObject] $E)

    $wezterm = _Tt-FindWezTerm
    if (-not $wezterm) {
        Write-Error "wezterm.exe not found. Install WezTerm or add it to PATH."
        return
    }
    $gui = _Tt-GuiBin $wezterm
    if (-not $gui) {
        Write-Error "wezterm-gui.exe not found next to $wezterm."
        return
    }

    $alias = _Tt-NormalizeHost $E.Host
    $session = $E.Session
    if ($alias.StartsWith('-') -or $alias -notmatch '^[A-Za-z0-9._-]{1,64}$') {
        Write-Error "tt: invalid host '$alias' -- must match [A-Za-z0-9._-]{1,64} and not start with '-'"
        return
    }
    if ($session.StartsWith('-') -or $session -notmatch '^[A-Za-z0-9._-]{1,64}$') {
        Write-Error "tt: invalid session '$session' -- must match [A-Za-z0-9._-]{1,64} and not start with '-'"
        return
    }

    $domain = if ($alias -eq 'WSL') { 'WSL' } else { $alias }
    $workspace = '{0}:{1}' -f $alias, $session
    # On Windows clients, passing a PROG/CWD spawn payload to a Unix mux can
    # serialize Windows OsString values and corrupt the remote PDU stream. Let
    # the remote mux spawn its default shell server-side instead.
    $wezArgs = @('connect', $domain, '--workspace', $workspace)
    Start-Process -FilePath $gui -ArgumentList $wezArgs | Out-Null
}

function tt {
    [CmdletBinding(DefaultParameterSetName = 'Pick')]
    param(
        [Parameter(ParameterSetName = 'Add')]
        [switch] $a,
        [Parameter(ParameterSetName = 'List')]
        [switch] $l,
        [Parameter(ParameterSetName = 'New')]
        [switch] $n,

        [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
        [string[]] $Patterns
    )

    $db  = _Tt-ReadDb
    _Tt-Seed $db
    $now = [DateTimeOffset]::Now.ToUnixTimeSeconds()

    if ($PSCmdlet.ParameterSetName -eq 'List') {
        $db.Values |
            Sort-Object -Property @{Expression={_Tt-Score $_ $now}; Descending=$true} |
            ForEach-Object {
                [PSCustomObject]@{
                    Host    = $_.Host
                    Session = $_.Session
                    Rank    = [math]::Round($_.Rank, 2)
                    Score   = [math]::Round((_Tt-Score $_ $now), 2)
                    Age     = if ($_.LastUsed) { "$([math]::Round(($now - $_.LastUsed) / 60, 0))m" } else { '-' }
                }
            } | Format-Table
        return
    }

    if ($PSCmdlet.ParameterSetName -eq 'New') {
        if (-not $Patterns -or $Patterns.Count -lt 2) {
            Write-Error "Usage: tt -n HOST SESSION"; return
        }
        $newHost    = _Tt-NormalizeHost $Patterns[0]
        $newSession = $Patterns[1]
        $key = "${newHost}`t${newSession}"
        if (-not $db.ContainsKey($key)) {
            $db[$key] = [PSCustomObject]@{ Host=$newHost; Session=$newSession; Rank=0.0; LastUsed=[int64]0 }
        }
        $db[$key].Rank += 1
        $db[$key].LastUsed = $now
        _Tt-WriteDb $db
        _Tt-Launch $db[$key]
        return
    }

    if ($PSCmdlet.ParameterSetName -eq 'Add') {
        if (-not $Patterns -or $Patterns.Count -lt 2) {
            Write-Error "Usage: tt -a HOST SESSION"; return
        }
        $addHost = _Tt-NormalizeHost $Patterns[0]
        $addSession = $Patterns[1]
        $key = "${addHost}`t${addSession}"
        if (-not $db.ContainsKey($key)) {
            $db[$key] = [PSCustomObject]@{ Host=$addHost; Session=$addSession; Rank=0.0; LastUsed=[int64]0 }
        }
        $db[$key].Rank += 1
        $db[$key].LastUsed = $now
        _Tt-WriteDb $db
        "Promoted: $addHost / $addSession (rank=$($db[$key].Rank))"
        return
    }

    $ranked = $db.Values | Sort-Object -Property @{Expression={_Tt-Score $_ $now}; Descending=$true}
    $pickedEntry = $null

    if ($Patterns -and $Patterns.Count -gt 0) {
        $needles = @($Patterns | ForEach-Object { $_.ToLower() })
        $pickedEntry = $ranked | Where-Object {
            $hs = ("$($_.Host) $($_.Session)").ToLower()
            $ok = $true
            foreach ($needle in $needles) {
                if (-not $hs.Contains($needle)) { $ok = $false; break }
            }
            $ok
        } | Select-Object -First 1

        if (-not $pickedEntry) {
            Write-Error ("No match for: {0}. Use 'tt -n HOST SESSION' to launch a new one." -f ($Patterns -join ' '))
            return
        }
    } else {
        $lines = $ranked | ForEach-Object { "$($_.Host)`t$($_.Session)" }
        $pick = ($lines -join "`n") | wsl.exe fzf --reverse --no-multi --prompt 'tt> ' `
                                         --delimiter "`t" --with-nth "1,2" `
                                         --header 'pick host/session (ranked by frecency)'
        if (-not $pick) { return }
        $h, $s = $pick -split "`t", 2
        $pickedEntry = $ranked | Where-Object { $_.Host -eq $h -and $_.Session -eq $s } | Select-Object -First 1
        if (-not $pickedEntry) {
            Write-Error "Picked entry not found in db"; return
        }
    }

    $pickedEntry.Rank += 1
    $pickedEntry.LastUsed = $now
    _Tt-WriteDb $db
    _Tt-Launch $pickedEntry
}
