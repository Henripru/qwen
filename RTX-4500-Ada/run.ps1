param(
    [string]$BindHost = "127.0.0.1",
    [int]$Port = 11434
)

$ErrorActionPreference = "Stop"

$llama = Join-Path $PSScriptRoot "build\bin\Release\llama-server.exe"
if (-not (Test-Path $llama)) {
    Write-Host "[run] llama-server.exe not built. Run: compile.ps1" -ForegroundColor Red
    exit 1
}

$modelsDir = Join-Path $PSScriptRoot ".." "models"
$model = Get-ChildItem -Path $modelsDir -Filter "*.gguf" -File -Recurse -ErrorAction SilentlyContinue |
         Where-Object { $_.Name -notmatch '(?i)mmproj' } |
         Sort-Object Length |
         Select-Object -First 1 -ExpandProperty FullName
if (-not $model) {
    Write-Host "[run] no .gguf found in $modelsDir — run download.ps1 first" -ForegroundColor Red
    exit 1
}

& $llama `
  -m $model -ngl 99 `
  -ctk q8_0 -ctv q8_0 `
  --fit on --fit-ctx 40960 `
  --ubatch-size 512 `
  --parallel 1 `
  --flash-attn on `
  --cache-ram -1 `
  --no-mmap `
  --jinja `
  --host $BindHost --port $Port
