param(
    [Parameter(Position = 0)]
    [string]$TextEntry,

    [string]$s,
    [string]$a,

    [switch]$Help
)

if ($Help) {
    Write-Host "uvid - log timestamped entries to a yearly log file"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  uvid `"text entry`" [-s `"source`"] [-a `"author`"]"
    Write-Host "  uvid              (interactive mode)"
    Write-Host ""
    Write-Host "Arguments:"
    Write-Host "  `"text entry`"   The text to log (required)"
    Write-Host "  -s `"source`"    Source of the entry (optional)"
    Write-Host "  -a `"author`"    Author of the entry (optional)"
    Write-Host "  -Help          Show this help message"
    Write-Host ""
    Write-Host "Log file: YEAR_uvid.log (created in the current directory)"
    Write-Host ""
    Write-Host "Example:"
    Write-Host "  uvid `"some insight`" -s `"book title`" -a `"John Doe`""
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
    # Non-interactive mode
    $sourceText = "( - )"
    $author = "[ - ]"

    if ($s) { $sourceText = "($s)" }
    if ($a) { $author = "[$a]" }

    if (-not $TextEntry) {
        Write-Host "Usage: uvid `"some text entry`" -s `"source`" -a `"author`""
        exit 1
    }

    Write-Entry "[$timestamp] $TextEntry $author $sourceText"
}
