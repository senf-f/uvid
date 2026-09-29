# Adapter over uvid.sh, the one implementation. See docs/adr/0001-powershell-adapter-over-bash.md

if ($args[0] -eq '--install') {
    $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if (($userPath -split ";") -contains $PSScriptRoot) {
        Write-Host "uvid is already in PATH."
    } else {
        [Environment]::SetEnvironmentVariable("PATH", "$userPath;$PSScriptRoot", "User")
        Write-Host "Installed. Open a new terminal and run 'uvid' from anywhere."
    }
    exit 0
}

# Full path: bare `bash` resolves to WSL's System32\bash.exe.
$bash = "$env:ProgramFiles\Git\bin\bash.exe"
if (-not (Test-Path $bash)) {
    Write-Host "uvid needs Git for Windows ($bash not found)."
    exit 1
}

# Git Bash strips quotes from argv, so args travel in an env var, each terminated by \x1f.
$env:UVID_ARGS = -join ($args | ForEach-Object { "$_" + [char]0x1f })
try {
    & $bash "$PSScriptRoot/uvid.sh"
    $code = $LASTEXITCODE
} finally {
    Remove-Item Env:UVID_ARGS -ErrorAction SilentlyContinue
}
exit $code
