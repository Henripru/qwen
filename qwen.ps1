param(
    [string]$Host = "127.0.0.1",
    [int]$Port    = 11434
)

$model      = "qwen3-35b"
$remoteBase = "http://${Host}:${Port}"

# Optional: verify the remote server is reachable before launching
try {
    Invoke-RestMethod -Uri "$remoteBase/health" -TimeoutSec 3 -ErrorAction Stop | Out-Null
    Write-Host "llama.cpp server reachable at $remoteBase" -ForegroundColor Green
} catch {
    Write-Warning "Could not reach $remoteBase — server may be down or unreachable."
}

# Configure local API auth for the llama.cpp server below.
$env:PYTHONUTF8                               = "1"
$env:ANTHROPIC_API_KEY                        = "llama-local"
$env:ANTHROPIC_AUTH_TOKEN                     = ""
$env:ANTHROPIC_BASE_URL                       = $remoteBase
$env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1"
$env:CLAUDE_CODE_USE_POWERSHELL_TOOL          = "1"

# --bare: disables OAuth/keychain reads so only ANTHROPIC_API_KEY is used.
# This avoids the "both claude.ai and ANTHROPIC_API_KEY set" warning.
& claude --bare --model $model @args
