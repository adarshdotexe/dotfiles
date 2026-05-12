<#
.SYNOPSIS
    tt — open a Windows Terminal tab into a remote tmux/sesh session,
    ranked by frecency (like zoxide).

.DESCRIPTION
    Tracks every (host, session) pair you've launched in $env:USERPROFILE\.config\tt\db.tsv.
    Each launch bumps that entry's rank and timestamp. On `tt` (no args), all
    known entries are piped through fzf (via wsl.exe), sorted with the highest
    frecency on top, so a single Enter resumes your latest work.

    Usage:
        tt                  # fzf picker (default: highest-frecency first)
        tt <query>          # fuzzy substring match against "HOST SESSION",
                            # picks the highest-frecency hit
        tt -a HOST SESSION  # add/promote without launching
        tt -l               # list (debug)

    Frecency formula (zoxide-style):
        score = rank * factor(age)
        factor: <1h -> 4x, <1d -> 2x, <1w -> 0.5x, else 0.25x

    Source from your $PROFILE:  . $HOME\repos\dotfiles\windows\tt.ps1
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
    # Replace literal `t with actual tab — PowerShell quirk: -f does not interpret `t.
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
    # Pull hosts from ssh config so the first invocation isn't an empty picker.
    # Sessions are NOT seeded from sesh.toml — sesh's job is to discover what
    # exists on each remote (tmux ls, zoxide, ssh hosts). tt just tracks which
    # (host, session) pairs YOU have launched, regardless of how sesh resolves
    # the session name on arrival.
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
    # WSL is a local "host" — tt launches directly without mosh.
    $hosts = @('WSL') + $hosts
    # Seed a default "main" entry per host so first-time `tt` shows something.
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
    # Prune: drop entries whose Host isn't in the current ssh config. Session
    # names are arbitrary (whatever sesh finds on the remote) so we don't
    # validate them. Renamed hosts lose their rank — re-promote via `tt -n`.
    $validHosts = @{}
    foreach ($h in $hosts) { $validHosts[$h] = $true }
    $toRemove = @()
    foreach ($k in $Db.Keys) {
        if (-not $validHosts.ContainsKey($Db[$k].Host)) { $toRemove += $k }
    }
    foreach ($k in $toRemove) { $Db.Remove($k) | Out-Null }
}

function _Tt-FindWt {
    $cmd = Get-Command wt.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($candidate in @(
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe",
        "$env:USERPROFILE\AppData\Local\Microsoft\WindowsApps\wt.exe"
    )) { if (Test-Path $candidate) { return $candidate } }
    return $null
}

function _Tt-Launch {
    param([PSCustomObject] $E)
    $wt = _Tt-FindWt
    if (-not $wt) {
        Write-Error "wt.exe not found. Install Windows Terminal or add it to PATH."
        return
    }
    $alias = $E.Host
    # Session name goes inside single-quoted bash strings — escape any `'`.
    $name  = $E.Session -replace "'", "'\''"
    # Build the remote command. We don't use `sesh connect` because:
    #   - mosh-server's exec'd shell environment makes sesh's tmux source
    #     unreliable (we saw "No connection found for 'pia'" even with
    #     pia-ai-agent running, while plain ssh worked fine).
    #   - tmux lives at /bin/tmux or /usr/bin/tmux which is in every default
    #     PATH, so a direct `tmux` call has no env dependencies.
    # Logic: if a tmux session starting with $name exists, attach to that
    # (prefix-match — "pia" → "pia-ai-agent"). Otherwise create $name.
    # sesh stays available for the interactive `<prefix>+K` picker inside tmux.
    # Uses [[ -n $m ]] (bash unquoted is safe inside [[ ]]) instead of [ -n
    # "$m" ] so we avoid embedding `"` inside the bash -lc "..." wrapper.
    $tmuxInner = "m=`$(tmux ls 2>/dev/null | awk -F: -v n='$name' 'index(`$1, n)==1{print `$1; exit}'); [[ -n `$m ]] && exec tmux attach -t `$m; exec tmux new -s '$name'"
    if ($alias -eq 'WSL') {
        # Local WSL — no mosh. TT_HOST_ALIAS so tmux's set-titles renders
        # "WSL:cwd" instead of the WSL distro name.
        $inner = "export TT_HOST_ALIAS=WSL; $tmuxInner"
        & $wt -w 0 new-tab --title "WSL:$($E.Session)" `
            wsl.exe --cd '~' -- bash -lc $inner
    } else {
        # Inject TT_HOST_ALIAS through to the remote shell so the inner tmux
        # title reflects the ssh-config alias (BAN, SC, UFLWPE) rather than the
        # remote hostname (dc4-container-xterm-28, etc.). mosh's "[mosh] " tag
        # is hard-coded and unavoidable.
        # `bash -lc` (login shell) sources /etc/profile + ~/.profile — mosh-
        # server's exec'd bash is neither interactive nor invoked-via-rsh so
        # without `-l` it skips both .bashrc and .profile.
        $inner     = "export TT_HOST_ALIAS=$alias; $tmuxInner"
        # MOSH_TITLE_NOPREFIX=1 — tells mosh-client to NOT prepend "[mosh] " to
        # the window title (read by mosh, undocumented but supported since 1.3).
        $remoteCmd = "MOSH_TITLE_NOPREFIX=1 LC_ALL=C.UTF-8 LANG=C.UTF-8 mosh $alias -- bash -lc `"$inner`""
        & $wt -w 0 new-tab --title "$alias`:$($E.Session)" `
            wsl.exe --cd '~' -- bash -lc $remoteCmd
    }
}

function tt {
    [CmdletBinding(DefaultParameterSetName = 'Pick')]
    param(
        [Parameter(ParameterSetName = 'Add')]
        [switch] $a,
        [Parameter(ParameterSetName = 'List')]
        [switch] $l,
        # -n HOST SESSION: explicit "new" — create+launch even if not in db
        [Parameter(ParameterSetName = 'New')]
        [switch] $n,

        # All remaining args. Pick: zoxide-style fuzzy patterns (all must match).
        # Add / New: positional HOST then SESSION.
        [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
        [string[]] $Patterns
    )

    $db  = _Tt-ReadDb
    _Tt-Seed $db
    $now = [DateTimeOffset]::Now.ToUnixTimeSeconds()

    # -l: list debug view
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

    # -n: explicit new — direct launch HOST + SESSION, create if missing
    if ($PSCmdlet.ParameterSetName -eq 'New') {
        if (-not $Patterns -or $Patterns.Count -lt 2) {
            Write-Error "Usage: tt -n HOST SESSION"; return
        }
        $newHost    = $Patterns[0]
        $newSession = $Patterns[1]
        $key = "${newHost}`t${newSession}"
        if (-not $db.ContainsKey($key)) {
            $db[$key] = [PSCustomObject]@{ Host=$newHost; Session=$newSession; Rank=0.0; LastUsed=[int64]0 }
        }
        $db[$key].Rank     += 1
        $db[$key].LastUsed  = $now
        _Tt-WriteDb $db
        _Tt-Launch $db[$key]
        return
    }

    # -a: add/promote without launching
    if ($PSCmdlet.ParameterSetName -eq 'Add') {
        if (-not $Patterns -or $Patterns.Count -lt 2) {
            Write-Error "Usage: tt -a HOST SESSION"; return
        }
        $addHost    = $Patterns[0]
        $addSession = $Patterns[1]
        $key = "${addHost}`t${addSession}"
        if (-not $db.ContainsKey($key)) {
            $db[$key] = [PSCustomObject]@{ Host=$addHost; Session=$addSession; Rank=0.0; LastUsed=[int64]0 }
        }
        $db[$key].Rank     += 1
        $db[$key].LastUsed  = $now
        _Tt-WriteDb $db
        "Promoted: $addHost / $addSession (rank=$($db[$key].Rank))"
        return
    }

    # Pick mode
    $ranked = $db.Values | Sort-Object -Property @{Expression={_Tt-Score $_ $now}; Descending=$true}

    $pickedEntry = $null
    if ($Patterns -and $Patterns.Count -gt 0) {
        # zoxide-style: every pattern must appear (case-insensitive) somewhere in
        # "<host> <session>". Highest-frecency hit wins.
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
        # Build TSV: HOST<TAB>SESSION, pipe to wsl fzf (--reverse so top item = top of screen).
        $lines = $ranked | ForEach-Object { "$($_.Host)`t$($_.Session)" }
        $listText = ($lines -join "`n")
        $pick = $listText | wsl.exe fzf --reverse --no-multi --prompt 'tt> ' `
                                       --delimiter "`t" --with-nth "1,2" `
                                       --header 'pick host/session (ranked by frecency)'
        if (-not $pick) { return }
        $h, $s = $pick -split "`t", 2
        $pickedEntry = $ranked | Where-Object { $_.Host -eq $h -and $_.Session -eq $s } | Select-Object -First 1
        if (-not $pickedEntry) {
            Write-Error "Picked entry not found in db"; return
        }
    }

    # Promote
    $pickedEntry.Rank     += 1
    $pickedEntry.LastUsed  = $now
    _Tt-WriteDb $db

    _Tt-Launch $pickedEntry
}
