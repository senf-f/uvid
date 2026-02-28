param(
    [Parameter(Position = 0)]
    [string]$TextEntry,

    [string]$s,
    [string]$a
)

# Default values
$sourceText = "( - )"
$author = "[ - ]"

if (-not $TextEntry) {
    Write-Host "Usage: uvid `"some text entry`" -s `"source`" -a `"author`""
    exit 1
}

if ($s) { $sourceText = "($s)" }
if ($a) { $author = "[$a]" }

# Create log file if it doesn't exist
$logFile = "$(Get-Date -Format 'yyyy')_uvid.log"
if (-not (Test-Path $logFile)) { New-Item $logFile -ItemType File | Out-Null }

# Get current timestamp
$timestamp = Get-Date -Format "dd.MM.yyyy HH:mm"

# Append entry to the log file
Add-Content -Path $logFile -Value "[$timestamp] $TextEntry $author $sourceText"

Write-Host "Entry added to $logFile"
