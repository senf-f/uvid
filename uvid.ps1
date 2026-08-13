param(
    [Parameter(Position = 0)]
    [string]$TextEntry,

    [string]$s,
    [string]$a,
    [string]$Search,
    [int]$List = 0,
    [switch]$Install,
    [switch]$Help,
    [switch]$Edit,
    [switch]$Delete,
    [switch]$Export,
    [switch]$Sync,
    [string]$Author,
    [int]$Year = 0,
    [string]$From,
    [string]$To,
    [string]$SetDevice,
    [switch]$ShowDevice
)

$UvidDir = if ($env:UVID_DIR) { $env:UVID_DIR } else { "$HOME/.uvid" }
if (-not (Test-Path $UvidDir)) { New-Item $UvidDir -ItemType Directory -Force | Out-Null }

$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)

$ScriptPath = $MyInvocation.MyCommand.Path

function Get-UvidDevice {
    if ($env:UVID_DEVICE) { return $env:UVID_DEVICE }
    $deviceFile = "$UvidDir/.uvid-device"
    if (Test-Path $deviceFile) {
        $name = (Get-Content $deviceFile -Encoding UTF8).Trim()
        if ($name -match '^[a-z0-9-]+$') { return $name }
    }
    $hostName = ($env:COMPUTERNAME ?? (hostname)).ToLower()
    if ($hostName -match '^[a-z0-9-]+$') { return $hostName }
    return ""
}

if ($Help) {
    Write-Host "uvid - log timestamped entries to a yearly log file"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  uvid `"text entry`" [-s `"source`"] [-a `"author`"]"
    Write-Host "  uvid              (interactive mode)"
    Write-Host ""
    Write-Host "Arguments:"
    Write-Host "  `"text entry`"      The text to log (required)"
    Write-Host "  -s `"source`"       Source of the entry (optional)"
    Write-Host "  -a `"author`"       Author of the entry (optional)"
    Write-Host ""
    Write-Host "Flags:"
    Write-Host "  -List n           Show last n entries from this month's log"
    Write-Host "  -Search `"term`"    Search all log files for a term"
    Write-Host "  -Edit             Edit an existing entry"
    Write-Host "  -Delete           Delete an existing entry"
    Write-Host "  -Export           Export entries to Markdown"
    Write-Host "    -Search `"term`"   Filter by text"
    Write-Host "    -Author `"name`"   Filter by author"
    Write-Host "    -Year YYYY       Filter by year"
    Write-Host "    -From/-To        Filter by date range (DD.MM.YYYY)"
    Write-Host "  -Sync             Sync logs with VPS"
    Write-Host "  -SetDevice name   Set device name for this machine"
    Write-Host "  -ShowDevice       Show device tags in list/search output"
    Write-Host "  -Install          Add uvid function to PowerShell profile"
    Write-Host "  -Help             Show this help message"
    Write-Host ""
    Write-Host "Log file: ~/.uvid/MM-YYYY_uvid.log"
    Write-Host ""
    Write-Host "Example:"
    Write-Host "  uvid `"some insight`" -s `"book title`" -a `"John Doe`""
    exit 0
}

if ($Install) {
    $scriptDir = Split-Path $ScriptPath
    $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if (($userPath -split ";") -contains $scriptDir) {
        Write-Host "uvid is already in PATH."
    } else {
        [Environment]::SetEnvironmentVariable("PATH", "$userPath;$scriptDir", "User")
        $env:PATH += ";$scriptDir"
        Write-Host "Installed. Open a new terminal and run 'uvid' from anywhere."
    }
    exit 0
}

if ($SetDevice) {
    if ($SetDevice -notmatch '^[a-z0-9-]+$') {
        Write-Host "Invalid device name. Use lowercase letters, numbers, and hyphens only."
        exit 1
    }
    [System.IO.File]::WriteAllText("$UvidDir/.uvid-device", $SetDevice, $Utf8NoBom)
    Write-Host "Device set to: $SetDevice"
    exit 0
}

if ($PSBoundParameters.ContainsKey('List')) {
    $n = if ($List -gt 0) { $List } else { 10 }
    $logFile = "$UvidDir/$(Get-Date -Format 'MM-yyyy')_uvid.log"
    if (-not (Test-Path $logFile)) {
        Write-Host "No log file found for this month."
        exit 0
    }
    Write-Host "Last $n entries from $logFile`:"
    Write-Host ""
    $lines = Get-Content $logFile -Tail $n -Encoding UTF8
    if ($ShowDevice) {
        $lines
    } else {
        $lines | ForEach-Object { $_ -replace ' \{[a-z0-9-]+\}$', '' }
    }
    exit 0
}

if ($PSBoundParameters.ContainsKey('Search')) {
    if (-not $Search) {
        Write-Host "Usage: uvid -Search `"term`""
        exit 1
    }
    $logFiles = Get-Item "$UvidDir/*_uvid.log" -ErrorAction SilentlyContinue
    if (-not $logFiles) {
        Write-Host "No log files found."
        exit 0
    }
    $results = Select-String -Path "$UvidDir/*_uvid.log" -Pattern $Search -CaseSensitive:$false
    if ($ShowDevice) {
        $results
    } else {
        $results | ForEach-Object {
            $_.Line = $_.Line -replace ' \{[a-z0-9-]+\}$', ''
            $_
        }
    }
    exit 0
}

function Write-Entry {
    param([string]$Entry)
    $logFile = "$UvidDir/$(Get-Date -Format 'MM-yyyy')_uvid.log"
    if (-not (Test-Path $logFile)) { New-Item $logFile -ItemType File | Out-Null }
    [System.IO.File]::AppendAllText($logFile, "$Entry`n", $Utf8NoBom)
    Write-Host ""
    Write-Host "Logged: $Entry"
    Write-Host "File:   $logFile"
}

function Parse-Entry {
    param([string]$Line)
    $result = @{ Timestamp = ""; Text = ""; Author = ""; Source = ""; Device = "" }

    # Extract timestamp
    if ($Line -match '^\[[\d.]+\s[\d:]+\]') {
        $result.Timestamp = $Matches[0]
    }

    $rest = ($Line -replace '^\[[\d.]+\s[\d:]+\]\s*', '')

    # Extract device tag (trailing {name})
    if ($rest -match '\{([a-z0-9-]+)\}$') {
        $result.Device = $Matches[1]
        $rest = ($rest -replace '\s*\{[a-z0-9-]+\}$', '')
    }

    # Extract source (trailing parenthesized text)
    if ($rest -match '\(([^)]+)\)$') {
        $result.Source = $Matches[1]
        $rest = ($rest -replace '\s*\([^)]+\)$', '')
    }

    # Extract author (trailing bracketed text)
    if ($rest -match '\[([^\]]+)\]$') {
        $result.Author = $Matches[1]
        $rest = ($rest -replace '\s*\[[^\]]+\]$', '')
    }

    $result.Text = $rest.TrimEnd()
    return $result
}

function Pick-Entry {
    $choice = Read-Host "Browse recent or search? (B/s)"
    if (-not $choice) { $choice = "b" }

    $entries = @()
    $files = @()

    if ($choice -eq "s") {
        $term = Read-Host "Search term"
        $logFiles = Get-Item "$UvidDir/*_uvid.log" -ErrorAction SilentlyContinue
        if (-not $logFiles) {
            Write-Host "No log files found."
            exit 0
        }
        $searchResults = Select-String -Path "$UvidDir/*_uvid.log" -Pattern $term -CaseSensitive:$false
        if (-not $searchResults) {
            Write-Host "No matches found."
            exit 0
        }
        foreach ($m in $searchResults) {
            $entries += $m.Line
            $files += $m.Path
        }
    } else {
        $logFile = "$UvidDir/$(Get-Date -Format 'MM-yyyy')_uvid.log"
        if (-not (Test-Path $logFile)) {
            Write-Host "No log file found for this month."
            exit 0
        }
        $content = Get-Content $logFile -Encoding UTF8
        if (-not $content) {
            Write-Host "No entries found."
            exit 0
        }
        $tail = $content | Select-Object -Last 10
        foreach ($line in $tail) {
            $entries += $line
            $files += (Resolve-Path $logFile).Path
        }
    }

    Write-Host ""
    for ($i = 0; $i -lt $entries.Count; $i++) {
        Write-Host "  $($i + 1). $($entries[$i])"
    }
    Write-Host ""
    $selection = Read-Host "Select entry number"

    $num = 0
    if (-not [int]::TryParse($selection, [ref]$num) -or $num -lt 1 -or $num -gt $entries.Count) {
        Write-Host "Invalid selection."
        exit 1
    }

    return @{
        Line = $entries[$num - 1]
        File = $files[$num - 1]
    }
}

if ($Edit) {
    $picked = Pick-Entry
    $parsed = Parse-Entry $picked.Line

    Write-Host ""
    Write-Host "Editing entry. Press Enter to keep current value."
    Write-Host ""

    $displayAuthor = if ($parsed.Author) { $parsed.Author } else { "(none)" }
    $displaySource = if ($parsed.Source) { $parsed.Source } else { "(none)" }

    $newText = Read-Host "Text [$($parsed.Text)]"
    $newAuthor = Read-Host "Author [$displayAuthor]"
    $newSource = Read-Host "Source [$displaySource]"

    # Keep current values if Enter pressed
    if (-not $newText) { $newText = $parsed.Text }

    # For author/source: Enter=keep, whitespace-only=clear
    if ($newAuthor -eq "") {
        $newAuthor = $parsed.Author
    } elseif ($newAuthor.Trim() -eq "") {
        $newAuthor = ""
    }

    if ($newSource -eq "") {
        $newSource = $parsed.Source
    } elseif ($newSource.Trim() -eq "") {
        $newSource = ""
    }

    # Reconstruct entry (preserve device tag)
    $newEntry = "$($parsed.Timestamp) $newText"
    if ($newAuthor) { $newEntry += " [$newAuthor]" }
    if ($newSource) { $newEntry += " ($newSource)" }
    if ($parsed.Device) { $newEntry += " {$($parsed.Device)}" }

    # Replace in file (only first match)
    $content = Get-Content $picked.File -Encoding UTF8
    $replaced = $false
    $newContent = @()
    foreach ($line in $content) {
        if ($line -eq $picked.Line -and -not $replaced) {
            $newContent += $newEntry
            $replaced = $true
        } else {
            $newContent += $line
        }
    }
    [System.IO.File]::WriteAllLines($picked.File, $newContent, $Utf8NoBom)

    Write-Host ""
    Write-Host "Updated: $newEntry"
    exit 0
}

if ($Delete) {
    $picked = Pick-Entry

    Write-Host ""
    Write-Host "  $($picked.Line)"
    Write-Host ""
    $confirm = Read-Host "Delete this entry? (Y/n)"

    if ($confirm -and $confirm -ne "y") {
        Write-Host "Cancelled."
        exit 0
    }

    $content = Get-Content $picked.File -Encoding UTF8
    $deleted = $false
    $newContent = @()
    foreach ($line in $content) {
        if ($line -eq $picked.Line -and -not $deleted) {
            $deleted = $true
        } else {
            $newContent += $line
        }
    }
    [System.IO.File]::WriteAllLines($picked.File, $newContent, $Utf8NoBom)

    Write-Host "Deleted."
    exit 0
}

if ($Sync) {
    $scriptDir = Split-Path $ScriptPath
    $confFile = Join-Path $scriptDir ".uvid-sync.conf"

    $VpsHost = ""
    $VpsUser = "root"
    $VpsDir = "~/uvid-logs"

    if (Test-Path $confFile) {
        foreach ($line in Get-Content $confFile) {
            if ($line -match '^\s*VPS_HOST\s*=\s*"?([^"]+)"?\s*$') { $VpsHost = $Matches[1] }
            if ($line -match '^\s*VPS_USER\s*=\s*"?([^"]+)"?\s*$') { $VpsUser = $Matches[1] }
            if ($line -match '^\s*VPS_DIR\s*=\s*"?([^"]+)"?\s*$') { $VpsDir = $Matches[1] }
        }
    }

    if (-not $VpsHost) {
        Write-Host "VPS_HOST is not set. Create $confFile with:"
        Write-Host "  VPS_HOST=`"your-host-or-alias`""
        exit 1
    }

    $remote = "$VpsUser@$VpsHost"

    # Prefer rsync (skips unchanged files); fall back to scp if unavailable.
    $haveRsync = [bool](Get-Command rsync -ErrorAction SilentlyContinue)
    if (-not $haveRsync) {
        Write-Host "Warning: rsync not found, falling back to scp (all files will be copied)."
    }

    Write-Host "Pushing local logs to VPS..."
    ssh $remote "mkdir -p $VpsDir/incoming"
    if ($haveRsync) {
        rsync -az "$UvidDir/*_uvid.log" "${remote}:$VpsDir/incoming/"
    } else {
        scp "$UvidDir/*_uvid.log" "${remote}:$VpsDir/incoming/"
    }

    Write-Host "Merging on VPS..."
    ssh $remote "bash $VpsDir/uvid-merge.sh $VpsDir/incoming"

    Write-Host "Cleaning up incoming..."
    ssh $remote "rm -f $VpsDir/incoming/*_uvid.log"

    Write-Host "Pulling merged logs..."
    if ($haveRsync) {
        rsync -az "${remote}:$VpsDir/*_uvid.log" "$UvidDir/"
    } else {
        scp "${remote}:$VpsDir/*_uvid.log" "$UvidDir/"
    }

    Write-Host "Sync complete."
    exit 0
}

if ($Export) {
    # Validate: -Year and -From/-To are mutually exclusive
    if ($Year -gt 0 -and ($From -or $To)) {
        Write-Host "Error: -Year and -From/-To cannot be combined."
        exit 1
    }

    # Validate: -From and -To must come together
    if (($From -and -not $To) -or (-not $From -and $To)) {
        Write-Host "Error: -From and -To must both be provided."
        exit 1
    }

    # Collect log files
    if ($Year -gt 0) {
        $logFiles = Get-Item "$UvidDir/*-${Year}_uvid.log" -ErrorAction SilentlyContinue | Sort-Object Name
    } else {
        $logFiles = Get-Item "$UvidDir/*_uvid.log" -ErrorAction SilentlyContinue | Sort-Object Name
    }

    if (-not $logFiles) {
        Write-Host "No entries found matching the given filters."
        exit 0
    }

    # Parse date range bounds
    $fromDate = $null
    $toDate = $null
    if ($From) {
        $fromDate = [datetime]::ParseExact($From, "dd.MM.yyyy", $null)
        $toDate = [datetime]::ParseExact($To, "dd.MM.yyyy", $null)
    }

    # Collect matching entries
    $matched = @()
    foreach ($file in $logFiles) {
        foreach ($line in (Get-Content $file.FullName -Encoding UTF8)) {
            if (-not $line) { continue }

            # Search filter
            if ($Search -and $line -notmatch [regex]::Escape($Search)) { continue }

            $parsed = Parse-Entry $line

            # Author filter
            if ($Author -and $parsed.Author -ne $Author) {
                if ($parsed.Author.ToLower() -ne $Author.ToLower()) { continue }
            }

            # Date range filter
            if ($fromDate) {
                $tsDate = $parsed.Timestamp -replace '[\[\]]', ''
                $entryDateStr = ($tsDate -split ' ')[0]
                $entryDate = [datetime]::ParseExact($entryDateStr, "dd.MM.yyyy", $null)
                if ($entryDate -lt $fromDate -or $entryDate -gt $toDate) { continue }
            }

            $matched += $line
        }
    }

    if ($matched.Count -eq 0) {
        Write-Host "No entries found matching the given filters."
        exit 0
    }

    # Build header title
    $title = "# Uvid Export"
    $parts = @()
    if ($Year -gt 0) {
        $parts += "$Year"
    } elseif ($From) {
        $parts += "$From - $To"
    }
    if ($Author) { $parts += $Author }
    if ($Search) { $parts += "`"$Search`"" }
    if ($parts.Count -gt 0) {
        $title += " - $($parts -join ', ')"
    }

    $exportDate = Get-Date -Format "dd.MM.yyyy"
    $exportFile = "uvid_export_$(Get-Date -Format 'yyyy-MM-dd').md"

    $output = @()
    $output += $title
    $output += "> $($matched.Count) entries | Exported $exportDate"
    $output += ""
    $output += "---"

    foreach ($line in $matched) {
        $parsed = Parse-Entry $line

        $output += ""
        $output += "**$($parsed.Timestamp)** $($parsed.Text)"

        $hasAuthor = $parsed.Author -and $parsed.Author -ne "."
        $hasSource = $parsed.Source -and $parsed.Source -ne "-"

        if ($hasAuthor -and $hasSource) {
            $output += "- Author: $($parsed.Author) | Source: $($parsed.Source)"
        } elseif ($hasAuthor) {
            $output += "- Author: $($parsed.Author)"
        } elseif ($hasSource) {
            $output += "- Source: $($parsed.Source)"
        }

        if ($parsed.Device) {
            $output += "- Device: $($parsed.Device)"
        }
    }

    [System.IO.File]::WriteAllLines($exportFile, $output, $Utf8NoBom)
    Write-Host "Exported $($matched.Count) entries to $exportFile"
    exit 0
}

$timestamp = Get-Date -Format "dd.MM.yyyy HH:mm:ss"

if ($PSBoundParameters.Count -eq 0) {
    # Interactive mode
    $TextEntry = Read-Host "Text"
    if (-not $TextEntry) {
        Write-Host "Text entry is required."
        exit 1
    }

    $sourceInput = Read-Host "Source [-]"
    if (-not $sourceInput) { $sourceInput = "-" }
    $authorInput = Read-Host "Author [.]"
    if (-not $authorInput) { $authorInput = "." }

    $entry = "[$timestamp] $TextEntry"
    if ($authorInput) { $entry += " [$authorInput]" }
    if ($sourceInput) { $entry += " ($sourceInput)" }
    $device = Get-UvidDevice
    if ($device) { $entry += " {$device}" }

    Write-Entry $entry
} else {
    # Inline mode
    if (-not $TextEntry) {
        Write-Host "Usage: uvid `"some text entry`" -s `"source`" -a `"author`""
        exit 1
    }

    if ($TextEntry -match '^-') {
        Write-Host "Unknown flag: $TextEntry"
        Write-Host "Run 'uvid -Help' for usage."
        exit 1
    }

    $entry = "[$timestamp] $TextEntry"
    if ($a) { $entry += " [$a]" }
    if ($s) { $entry += " ($s)" }
    $device = Get-UvidDevice
    if ($device) { $entry += " {$device}" }

    Write-Entry $entry
}
