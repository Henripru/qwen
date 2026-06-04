$ErrorActionPreference = "Stop"

Write-Host "[install] Installing Python dependencies..." -ForegroundColor Cyan
py -m pip install --upgrade huggingface_hub
Write-Host "[install] Done." -ForegroundColor Green
