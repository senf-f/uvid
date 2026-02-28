param(
    [Parameter(Position = 0)]
    [string]$TextEntry,

    [string]$s,
    [string]$a,
    [string]$Search,
    [int]$List = 0,
    [switch]$Install,
    [switch]$Help
)

$ScriptPath = $MyInvocation.MyCommand.Path

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
    Write-Host "  -List n           Show last n entries from this year's log"
    Write-Host "  -Search `"term`"    Search all log files for a term"
    Write-Host "  -Install          Add uvid function to PowerShell profile"
    Write-Host "  -Help             Show this help message"
    Write-Host ""
    Write-Host "Log file: YEAR_uvid.log (created in the current directory)"
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

if ($PSBoundParameters.ContainsKey('List')) {
    $n = if ($List -gt 0) { $List } else { 10 }
    $logFile = "$(Get-Date -Format 'yyyy')_uvid.log"
    if (-not (Test-Path $logFile)) {
        Write-Host "No log file found for this year."
        exit 0
    }
    Write-Host "Last $n entries from $logFile`:"
    Write-Host ""
    Get-Content $logFile -Tail $n
    exit 0
}

if ($PSBoundParameters.ContainsKey('Search')) {
    if (-not $Search) {
        Write-Host "Usage: uvid -Search `"term`""
        exit 1
    }
    $logFiles = Get-Item *_uvid.log -ErrorAction SilentlyContinue
    if (-not $logFiles) {
        Write-Host "No log files found."
        exit 0
    }
    Select-String -Path *_uvid.log -Pattern $Search -CaseSensitive:$false
    exit 0
}

function Write-Entry {
    param([string]$Entry)
    $logFile = "$(Get-Date -Format 'yyyy')_uvid.log"
    if (-not (Test-Path $logFile)) { New-Item $logFile -ItemType File | Out-Null }
    Add-Content -Path $logFile -Value $Entry
    Write-Host ""
    Write-Host "Logged: $Entry"
    Write-Host "File:   $logFile"
}

$timestamp = Get-Date -Format "dd.MM.yyyy HH:mm"

if ($PSBoundParameters.Count -eq 0) {
    # Interactive mode
    $TextEntry = Read-Host "Text"
    if (-not $TextEntry) {
        Write-Host "Text entry is required."
        exit 1
    }

    $sourceInput = Read-Host "Source"
    $authorInput = Read-Host "Author"

    $entry = "[$timestamp] $TextEntry"
    if ($authorInput) { $entry += " [$authorInput]" }
    if ($sourceInput) { $entry += " ($sourceInput)" }

    Write-Entry $entry
} else {
    # Inline mode
    if (-not $TextEntry) {
        Write-Host "Usage: uvid `"some text entry`" -s `"source`" -a `"author`""
        exit 1
    }

    $entry = "[$timestamp] $TextEntry"
    if ($a) { $entry += " [$a]" }
    if ($s) { $entry += " ($s)" }

    Write-Entry $entry
}
