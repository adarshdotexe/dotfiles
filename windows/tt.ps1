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

# Base64-encoded helper script body (source: dotfiles/windows/tt-launch.sh).
# Regenerate via: base64 -w0 dotfiles/windows/tt-launch.sh
$script:TtLaunchB64 = 'IyEvdXNyL2Jpbi9lbnYgYmFzaAojIHR0LWxhdW5jaCDigJQgcmVtb3RlIGF0dGFjaCBoZWxwZXIuIEVtYmVkZGVkIGFzIGJhc2U2NCBpbiB0dC5wczEgLyB0dC56c2guCiMKIyBUaGlzIGZpbGUgaXMgdGhlIFNPVVJDRSBPRiBUUlVUSC4gVGhlIHdyYXBwZXJzICh0dC5wczEsIHR0LnpzaCkgYmFzZTY0LWVuY29kZQojIGl0cyBjb250ZW50cyBpbnRvIGEgY29uc3RhbnQuIE9uIGVhY2ggbGF1bmNoIHRoZSB3cmFwcGVyIHdyaXRlcyBhIGZyZXNoIGNvcHkKIyB0byB+Ly5sb2NhbC9iaW4vdHQtbGF1bmNoIG9uIHRoZSByZW1vdGUgYW5kIGV4ZWMncyBgYmFzaCA8ZmlsZT4gU0VTU0lPTmAgc28KIyB0aGF0IG1vc2gncyBQVFkgc3Vydml2ZXMgb24gc3RkaW4gKHBpcGluZyB0byBgYmFzaGAgd291bGQgcmVwbGFjZSBzdGRpbiB3aXRoCiMgdGhlIHBpcGUgYW5kIHRtdXggYXR0YWNoIHdvdWxkIGZhaWwgd2l0aCAib3BlbiB0ZXJtaW5hbCBmYWlsZWQ6IG5vdCBhCiMgdGVybWluYWwiKS4KIwojIFVzYWdlOiB0dC1sYXVuY2ggU0VTU0lPTgpzZXQgLWV1byBwaXBlZmFpbAoKIyBBbHdheXMtb24gdHJhY2UuIExpdmVzIGF0IH4vLmNhY2hlL3R0LWxhdW5jaC9sYXN0LWxhdW5jaC50cmFjZSBvbiB0aGUgcmVtb3RlLgpUUkFDRV9ESVI9IiRIT01FLy5jYWNoZS90dC1sYXVuY2giCm1rZGlyIC1wICIkVFJBQ0VfRElSIgpleGVjIDk+IiRUUkFDRV9ESVIvbGFzdC1sYXVuY2gudHJhY2UiCkJBU0hfWFRSQUNFRkQ9OQpQUzQ9JysgWyQoZGF0ZSArJUg6JU06JVMpXSAke0JBU0hfU09VUkNFIyMqL306JHtMSU5FTk99OiAnCnNldCAteAoKIyBWYWxpZGF0ZSBzZXNzaW9uIG5hbWUgKGRlZmVuc2UgaW4gZGVwdGgg4oCUIGFscmVhZHkgY2hlY2tlZCBob3N0LXNpZGUpLgpTRVNTSU9OPSIkezE6P21pc3Npbmcgc2Vzc2lvbiBuYW1lfSIKY2FzZSAiJFNFU1NJT04iIGluCiAgLSopIGVjaG8gInR0LWxhdW5jaDogc2Vzc2lvbiBtdXN0IG5vdCBzdGFydCB3aXRoICctJyIgPiYyOyBleGl0IDIgOzsKZXNhYwpwcmludGYgJyVzJyAiJFNFU1NJT04iIHwgZ3JlcCAtRXEgJ15bQS1aYS16MC05Ll8tXXsxLDY0fSQnIFwKICB8fCB7IGVjaG8gInR0LWxhdW5jaDogaW52YWxpZCBzZXNzaW9uIG5hbWUiID4mMjsgZXhpdCAyOyB9CgojIEV4cGxpY2l0IGVudiBhY3RpdmF0aW9uIOKAlCBsb2dpbiBiYXNoIG9uIFJvY2t5IDggZG9lc24ndCBzb3VyY2UgLmJhc2hyYywgYW5kCiMgbWljcm9tYW1iYSBhY3RpdmF0aW9uIGxpdmVzIGluIC5iYXNocmMgb24gdGhlc2UgaG9zdHMuIFNvdXJjZSB0aGUgdXN1YWwKIyBzdGFydHVwIGZpbGVzIHNvIFBBVEggcGlja3MgdXAgfi8ubG9jYWwvYmluIChzZXNoLCBtaWNyb21hbWJhKS4KIwojIFJlbGF4IHN0cmljdG5lc3MgYXJvdW5kIHRoZSBzb3VyY2VzOiBkaXN0cm9zJyByYyBmaWxlcyByb3V0aW5lbHkgcmVmZXJlbmNlCiMgdW5zZXQgdmFyaWFibGVzICgkSElTVENPTlRST0wsICRQUzEsIOKApikgd2hpY2ggdHJpcCBgc2V0IC11YCwgYW5kIHRoZXkgdXNlCiMgcGlwZWxpbmVzIHRoYXQgbWF5IGxlZ2l0aW1hdGVseSBoYXZlIG5vbi16ZXJvIGV4aXRzICgkcGlwZWZhaWwpLiBSZXN0b3JlCiMgdGhlIHN0cmljdCBtb2RlIGFmdGVyd2FyZHMuCnNldCArZXVvIHBpcGVmYWlsClsgLXIgL2V0Yy9wcm9maWxlIF0gJiYgLiAvZXRjL3Byb2ZpbGUKWyAtciAiJEhPTUUvLnByb2ZpbGUiIF0gJiYgLiAiJEhPTUUvLnByb2ZpbGUiClsgLXIgIiRIT01FLy5iYXNocmMiIF0gJiYgLiAiJEhPTUUvLmJhc2hyYyIKc2V0IC1ldW8gcGlwZWZhaWwKCiMgTWljcm9tYW1iYSBhY3RpdmF0aW9uIChuby1vcCBpZiBhYnNlbnQpLiBBY3RpdmF0ZXMgdGhlIGBkb3RmaWxlc2AgZW52IGlmCiMgcHJlc2VudCBzbyB0bXV4L3Nlc2ggZnJvbSB0aGF0IGVudiBsYW5kIG9uIFBBVEguCmlmIFsgLXggIiRIT01FLy5sb2NhbC9iaW4vbWljcm9tYW1iYSIgXTsgdGhlbgogIGV4cG9ydCBNQU1CQV9FWEU9IiRIT01FLy5sb2NhbC9iaW4vbWljcm9tYW1iYSIKICBleHBvcnQgTUFNQkFfUk9PVF9QUkVGSVg9IiR7TUFNQkFfUk9PVF9QUkVGSVg6LSRIT01FLy5sb2NhbC9taWNyb21hbWJhfSIKICBldmFsICIkKCIkTUFNQkFfRVhFIiBzaGVsbCBob29rIC0tc2hlbGwgYmFzaCkiCiAgWyAtZCAiJE1BTUJBX1JPT1RfUFJFRklYL2VudnMvZG90ZmlsZXMiIF0gJiYgbWljcm9tYW1iYSBhY3RpdmF0ZSBkb3RmaWxlcwpmaQoKZXhwb3J0IFRUX0hPU1RfQUxJQVM9IiR7VFRfSE9TVF9BTElBUzotJHtIT1NUTkFNRSUlLip9fSIKCiMgQnJvd3NlciBicmlkZ2U6IGFueSBwcm9jZXNzIHRoYXQgb3BlbnMgYSBVUkwgaW5zaWRlIHRoaXMgc2Vzc2lvbiBpcyByb3V0ZWQKIyB0aHJvdWdoIH4vLmxvY2FsL2Jpbi90dC1vcGVuLCB3aGljaCBQT1NUcyB0byB0aGUgV2luZG93cy1zaWRlIGxpc3RlbmVyIG92ZXIKIyB0aGUgZXQgcmV2ZXJzZS10dW5uZWwuIE91dHNpZGUgYW4gZXQgc2Vzc2lvbiB0aGUgY3VybCBmYWlscyBmYXN0IChzZWUKIyB0dC1vcGVuKS4gVGhlIHdyYXBwZXIgZXhwb3J0cyBCUk9XU0VSIGFscmVhZHksIGJ1dCB3ZSByZS1zZXQgaXQgaGVyZSBzbwojIGB0bXV4IG5ldy1zZXNzaW9uYCBpbmhlcml0cyBpdCBjbGVhbmx5IGludG8gdGhlIHNlc3Npb24gZW52LgppZiBbIC14ICIkSE9NRS8ubG9jYWwvYmluL3R0LW9wZW4iIF07IHRoZW4KICBleHBvcnQgQlJPV1NFUj0iJEhPTUUvLmxvY2FsL2Jpbi90dC1vcGVuIgpmaQoKIyB0bXV4IG11c3QgYmUgb24gUEFUSC4KY29tbWFuZCAtdiB0bXV4ID4vZGV2L251bGwgfHwgeyBlY2hvICJ0dC1sYXVuY2g6IHRtdXggbm90IG9uIFBBVEgiID4mMjsgZXhpdCAzOyB9CgojIDItdGllciBhdHRhY2ggbGFkZGVyOgojICAgMS4gc2VzaCBjb25uZWN0IOKAlCBoYW5kbGVzIGV4aXN0aW5nLXRtdXggKHByZWZpeCBtYXRjaCkgQU5EIHpveGlkZS1wYXRoIGNyZWF0ZQojICAgMi4gZmFsbGJhY2s6IHRtdXggbmV3LXNlc3Npb24gLUFzIOKAlCBmb3IgZ2VudWluZWx5LW5ldyBzZXNzaW9ucyBzZXNoIGRvZXNuJ3Qga25vdwppZiBjb21tYW5kIC12IHNlc2ggPi9kZXYvbnVsbCAyPiYxOyB0aGVuCiAgZXhlYyBzZXNoIGNvbm5lY3QgIiRTRVNTSU9OIiB8fCB0cnVlCmZpCmV4ZWMgdG11eCBuZXctc2Vzc2lvbiAtQXMgIiRTRVNTSU9OIgo='

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
    $alias   = $E.Host
    $session = $E.Session
    # Defense-in-depth session-name validation. The remote helper re-validates,
    # but rejecting here stops any wt/wsl tab from opening on bad input.
    if ($session.StartsWith('-') -or $session -notmatch '^[A-Za-z0-9._-]{1,64}$') {
        Write-Error "tt: invalid session name '$session' -- must match [A-Za-z0-9._-]{1,64} and not start with '-'"
        return
    }
    # NOTE: the URL-bridge listener lives in WSL, not on Windows. ET runs in
    # WSL, so the `-rt 8765:127.0.0.1:8765` tunnel's destination is WSL's
    # localhost. tt-et-launch.sh spawns the WSL-side tt-listener.py before
    # invoking et.
    $distro = if ($env:TT_WSL_DISTRO) { $env:TT_WSL_DISTRO } else { 'Ubuntu' }
    $b64 = $script:TtLaunchB64
    if ($alias -eq 'WSL') {
        # Local WSL — no transport. The remote helper deploys itself fresh
        # from the embedded base64 each launch so this path stays consistent
        # with the et path (same helper, same env activation).
        $remote = "export TT_HOST_ALIAS='WSL' && export BROWSER=tt-open && mkdir -p ~/.local/bin && echo $b64 | base64 -d > ~/.local/bin/tt-launch && chmod 0755 ~/.local/bin/tt-launch && exec bash ~/.local/bin/tt-launch '$session'"
        & $wt -w 0 new-tab --title "WSL:$session" wsl.exe -d $distro -- bash -c $remote
    } else {
        # Remote via EternalTerminal. tt-et-launch (WSL-side helper installed
        # by bootstrap.sh) handles: starting etserver on the remote via SSH if
        # it's not running, opening the reverse tunnel for the URL bridge, and
        # invoking et with the inner tt-launch payload as a positional arg.
        #
        # IMPORTANT: wt's new-tab joins argv after `--` with spaces, dropping
        # any quoting we'd build for `"$@"`. We side-step this by baking the
        # actual args into a single bash -lc string. Safe because:
        #   - $alias  was matched against the ssh-config Host list above
        #   - $session passed `^[A-Za-z0-9._-]{1,64}$` validation
        #   - $b64    is plain A-Z 0-9 + / =
        # None of those need shell escaping.
        $bashCmd = "tt-et-launch '$alias' '$session' $b64"
        $wtArgs = @(
            '-w','0','new-tab','--title',"${alias}:${session}",
            '--',
            'wsl.exe','-d',$distro,'--',
            'bash','-lc',$bashCmd
        )
        & $wt @wtArgs
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
