# Natter installer for Windows.
#
# In PowerShell (press Start, type "PowerShell", open it), paste:
#   irm https://raw.githubusercontent.com/advert-clicker/Natter-Status/refs/heads/main/install.ps1 | iex
#
# Installs Natter into your user folder (C:\Users\<you>\Natter). It never needs administrator rights.
# Written for Windows PowerShell 5.1 (the one that ships with Windows 10/11) and newer.

function Install-Natter {
    $ErrorActionPreference = 'Stop'
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
    try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

    $RepoRaw = $env:NATTER_REPO_RAW
    if (-not $RepoRaw) { $RepoRaw = 'https://raw.githubusercontent.com/advert-clicker/Natter-Status/refs/heads/main' }
    $Dest = $env:NATTER_DIR
    if (-not $Dest) { $Dest = Join-Path $env:USERPROFILE 'Natter' }
    $Work = Join-Path ([IO.Path]::GetTempPath()) ('natter-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $Work -Force | Out-Null

    # Box-drawing characters, built from code points so the file itself stays plain ASCII.
    $TL = [string][char]0x250C; $TR = [string][char]0x2510; $BL = [string][char]0x2514; $BR = [string][char]0x2518
    $HZ = [string][char]0x2500; $VT = [string][char]0x2502
    $Bullet = [string][char]0x2022

    function Say($text = '')        { Write-Host ('  ' + $text) }
    function Good($text)            { Write-Host '  ' -NoNewline; Write-Host 'OK ' -ForegroundColor Green -NoNewline; Write-Host $text }
    function Warn($text)            { Write-Host '  ' -NoNewline; Write-Host '!  ' -ForegroundColor Yellow -NoNewline; Write-Host $text }
    function Box($lines, $color) {
        Write-Host ('  ' + $TL + ($HZ * 46) + $TR) -ForegroundColor $color
        foreach ($l in $lines) { Write-Host ('  ' + $VT) -ForegroundColor $color -NoNewline; Write-Host $l.PadRight(46) -NoNewline; Write-Host $VT -ForegroundColor $color }
        Write-Host ('  ' + $BL + ($HZ * 46) + $BR) -ForegroundColor $color
    }
    function Step($n, $total, $title) {
        Write-Host ''
        Write-Host ('  Step ' + $n + ' of ' + $total + '  ') -ForegroundColor Cyan -NoNewline
        Write-Host $title -ForegroundColor White
        Write-Host ('  ' + ($HZ * 46)) -ForegroundColor DarkGray
    }
    function Fail($what) {
        Write-Host ''
        Write-Host '  Sorry - something went wrong.' -ForegroundColor Red
        Say $what
        Write-Host ''
        Say 'Nothing on your computer was harmed.'
        Say 'If you ask someone for help, show them this message.'
        Write-Host ''
        throw 'natter-install-stopped'
    }

    # Run a script block in the background while showing a little spinner. Returns what the block returns.
    function Work($message, [scriptblock]$block, $arguments) {
        $job = Start-Job -ScriptBlock $block -ArgumentList $arguments
        $frames = @('|', '/', '-', '\')
        $i = 0
        while ($job.State -eq 'Running') {
            Write-Host ("`r  " + $frames[$i % 4] + ' ' + $message + '   ') -ForegroundColor Cyan -NoNewline
            $i++
            Start-Sleep -Milliseconds 120
        }
        Write-Host ("`r" + (' ' * 78) + "`r") -NoNewline
        try {
            $result = Receive-Job -Job $job -ErrorAction Stop
            Remove-Job -Job $job -Force
            Good $message
            return $result
        } catch {
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            Write-Host '  ' -NoNewline; Write-Host 'X  ' -ForegroundColor Red -NoNewline; Write-Host $message
            throw
        }
    }

    function Find-Python {
        $candidates = @(@('py', '-3'), @('python'), @('python3'))
        foreach ($c in $candidates) {
            try {
                $exe = $c[0]
                $rest = @()
                if ($c.Count -gt 1) { $rest = $c[1..($c.Count - 1)] }
                $out = & $exe @rest -c 'import sys; print(sys.version_info >= (3, 8))' 2>$null
                if ($LASTEXITCODE -eq 0 -and ("$out".Trim() -eq 'True')) { return ,($c) }
            } catch {}
        }
        # A fresh per-user Python is not on PATH until you reopen the window, so look where the installer puts it.
        $found = Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA 'Programs\Python') -Filter python.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { return ,(@($found.FullName)) }
        return $null
    }

    try {
        Clear-Host
        Write-Host ''
        Box @('', '     N A T T E R', '     Private chat for you and your friends', '') 'Magenta'
        Write-Host ''
        Say 'This will put Natter on your computer. It takes about a minute.'
        Write-Host ''
        Say 'OK  You do not need to type anything technical.'
        Say 'OK  It only adds one folder, called Natter, to your user folder.'
        Say 'OK  You never need an administrator password.'
        Write-Host ''
        [void](Read-Host '  Press Enter to begin')

        # ---------------------------------------------------------------------------------------------- 1
        Step 1 4 'Checking your computer'
        Good 'Your computer is a Windows PC - perfect'
        $py = Find-Python
        if ($py) {
            Good 'Everything Natter needs is already here'
        } else {
            Warn 'Natter needs a small free helper program (Python), and it is not here yet.'
            $winget = Get-Command winget -ErrorAction SilentlyContinue
            if (-not $winget) {
                Start-Process 'https://www.python.org/downloads/'
                Fail ('I opened the Python download page for you. Install it (tick "Add python.exe to PATH"), then run this installer again.')
            }
            $answer = Read-Host '  Add it now? It is free and safe. [Y/n]'
            if ($answer -match '^(n|no)$') { Fail 'Natter cannot run without that helper. Run this installer again whenever you are ready.' }
            Write-Host ''
            Say 'Adding the helper program. Windows may show a progress bar - just wait.'
            & winget install -e --id Python.Python.3.12 --scope user --silent --accept-package-agreements --accept-source-agreements | Out-Null
            $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
            $py = Find-Python
            if (-not $py) { Fail 'The helper program did not finish installing. Please close this window, open PowerShell again, and re-run the installer.' }
            Good 'The helper program is ready'
        }
        $pyExe = $py[0]
        $pyRest = @()
        if ($py.Count -gt 1) { $pyRest = $py[1..($py.Count - 1)] }

        # ---------------------------------------------------------------------------------------------- 2
        Step 2 4 'Downloading Natter'
        $zipPath = Join-Path $Work 'natter.zip'
        $info = Work 'Getting the latest version' {
            param($repo, $zip)
            try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
            $stamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            $v = (Invoke-WebRequest -UseBasicParsing -Uri ($repo + '/version.txt?t=' + $stamp)).Content -split '\s+' | Where-Object { $_ }
            if ($v.Count -lt 2 -or $v[0] -notmatch '^[0-9]+$' -or $v[1] -notmatch '^[0-9a-f]{64}$') { throw 'The update information looks wrong.' }
            $name = 'natter-share.zip'
            if ($v.Count -gt 2) { $name = $v[2] }
            if ($name -notmatch '^[A-Za-z0-9._-]+\.zip$') { throw 'The update information looks wrong.' }
            Invoke-WebRequest -UseBasicParsing -Uri ($repo + '/' + $name + '?t=' + $stamp) -OutFile $zip
            $got = (Get-FileHash -Path $zip -Algorithm SHA256).Hash.ToLower()
            if ($got -ne $v[1]) { throw 'The download did not match its checksum.' }
            return $v[0]
        } @($RepoRaw, $zipPath)
        Good ('Version ' + ($info | Select-Object -Last 1) + ' downloaded and checked')

        # ---------------------------------------------------------------------------------------------- 3
        Step 3 4 'Installing'
        $unpack = @'
import sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
for n in z.namelist():
    p = n.split("/")
    if n.startswith("/") or ".." in p or "\\" in n:
        raise SystemExit("unsafe file name in download: " + n)
z.extractall(sys.argv[2])
'@
        $unpackPy = Join-Path $Work 'unpack.py'
        Set-Content -Path $unpackPy -Value $unpack -Encoding ASCII
        $out = Join-Path $Work 'out'
        & $pyExe @pyRest $unpackPy $zipPath $out
        if ($LASTEXITCODE -ne 0) { Fail 'The download looked damaged, so I did not install it.' }
        if (-not (Test-Path (Join-Path $out 'natter\src\index.html')) -or -not (Test-Path (Join-Path $out 'natter\update.py'))) { Fail 'The download looked incomplete, so I did not install it.' }
        $old = $Dest + '.old'
        if (Test-Path $old) { Remove-Item -Recurse -Force $old }
        try {
            if (Test-Path $Dest) { Move-Item -Path $Dest -Destination $old }
        } catch {
            Fail 'Natter seems to be running right now. Please close its window (the black one) and run this installer again.'
        }
        Move-Item -Path (Join-Path $out 'natter') -Destination $Dest
        if (Test-Path $old) { Remove-Item -Recurse -Force $old -ErrorAction SilentlyContinue }
        Good ('Natter is now in ' + $Dest)

        # ---------------------------------------------------------------------------------------------- 4
        Step 4 4 'Making it easy to open'
        try {
            $shell = New-Object -ComObject WScript.Shell
            $targets = @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Programs'))
            foreach ($folder in $targets) {
                if (-not $folder) { continue }
                $link = $shell.CreateShortcut((Join-Path $folder 'Natter.lnk'))
                $link.TargetPath = Join-Path $Dest 'start-windows.bat'
                $link.WorkingDirectory = $Dest
                $link.Description = 'Private chat for you and your friends'
                $link.IconLocation = (Join-Path $env:SystemRoot 'System32\SHELL32.dll') + ',13'
                $link.Save()
            }
            Good 'Added a Natter icon to your Desktop and Start menu'
        } catch {
            Warn 'I could not add a shortcut, but Natter still works. Open the Natter folder and double-click start-windows.bat.'
        }

        Write-Host ''
        Box @('', '   Natter is ready!', '') 'Green'
        Write-Host ''
        Say 'Any time you want to chat, double-click the Natter icon on your Desktop.'
        Say 'The first time, just pick a name - your account is made for you.'
        Say 'Natter updates itself every time it starts.'
        Write-Host ''
        $open = Read-Host '  Open Natter now? [Y/n]'
        if ($open -notmatch '^(n|no)$') {
            Write-Host ''
            Say 'Starting... (keep the black window open while you chat)'
            Start-Process -FilePath (Join-Path $Dest 'start-windows.bat') -WorkingDirectory $Dest
        }
        Write-Host ''
        Say 'All done. Enjoy!'
        Write-Host ''
    } catch {
        if ($_.Exception.Message -ne 'natter-install-stopped') {
            Write-Host ''
            Write-Host '  Sorry - something went wrong.' -ForegroundColor Red
            Say $_.Exception.Message
            Write-Host ''
            Say 'Nothing on your computer was harmed. You can run the installer again.'
            Write-Host ''
        }
    } finally {
        Remove-Item -Recurse -Force $Work -ErrorAction SilentlyContinue
    }
}

Install-Natter
