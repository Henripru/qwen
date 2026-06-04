$ErrorActionPreference = "Stop"

Write-Host "[setup] Setting CLAUDE_CODE_USE_POWERSHELL_TOOL permanently..." -ForegroundColor Cyan

[System.Environment]::SetEnvironmentVariable(
    "CLAUDE_CODE_USE_POWERSHELL_TOOL",
    "1",
    [System.EnvironmentVariableTarget]::User
)

Write-Host "[setup] Done. The variable is now set for all future sessions." -ForegroundColor Green
Write-Host "[setup] Open a new terminal or run the following to apply immediately:" -ForegroundColor Yellow
Write-Host '  $env:CLAUDE_CODE_USE_POWERSHELL_TOOL = "1"' -ForegroundColor Gray
