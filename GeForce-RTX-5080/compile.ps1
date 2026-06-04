# compile.ps1 — Clone and build llama.cpp for RTX 5080 (Blackwell SM_120)
# Outputs llama-server.exe to .\build\bin\ where qwen-moe-turbo.ps1 expects it.
#
# Requirements: CUDA Toolkit 12.8, Visual Studio 2022, CMake, Git
# Run once; re-run to rebuild after updates.

$ErrorActionPreference = "Stop"

$root      = $PSScriptRoot
$srcDir    = Join-Path $root "llama.cpp"
$buildDir  = Join-Path $root "build"
$serverExe = Join-Path $buildDir "bin\Release\llama-server.exe"

# ── Verify CUDA 12.8 is on PATH ─────────────────────────────────────────────
$nvcc = Get-Command nvcc -ErrorAction SilentlyContinue
if (-not $nvcc) {
    Write-Host "[compile] nvcc not found — install CUDA Toolkit 12.8 from developer.nvidia.com/cuda-toolkit-archive" -ForegroundColor Red
    exit 1
}
$cudaVer = (nvcc --version 2>&1 | Select-String "release (\d+\.\d+)" | ForEach-Object { $_.Matches[0].Groups[1].Value })
Write-Host "[compile] CUDA $cudaVer detected" -ForegroundColor Cyan
if ($cudaVer -and [version]$cudaVer -ge [version]"13.0") {
    Write-Host "[compile] WARNING: CUDA 13.x may cause crashes on Blackwell with llama.cpp. Recommend 12.8." -ForegroundColor Yellow
}

# ── Clone llama.cpp (skip if already present) ────────────────────────────────
if (Test-Path (Join-Path $srcDir ".git")) {
    Write-Host "[compile] llama.cpp already cloned — pulling latest..." -ForegroundColor Cyan
    git -C $srcDir pull
} else {
    Write-Host "[compile] Cloning llama.cpp..." -ForegroundColor Cyan
    git clone --depth 1 https://github.com/ggerganov/llama.cpp $srcDir
}

# ── CMake configure ──────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[compile] Configuring (Blackwell SM_120, CUDA, Flash Attention)..." -ForegroundColor Cyan
cmake -S $srcDir -B $buildDir `
    -DGGML_CUDA=ON `
    -DCMAKE_CUDA_ARCHITECTURES=120 `
    -DGGML_CUDA_FA_ALL_QUANTS=ON `
    -DCMAKE_BUILD_TYPE=Release

# ── Build ────────────────────────────────────────────────────────────────────
Write-Host ""
$cores = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
Write-Host "[compile] Building with $cores threads (this takes 10-20 min)..." -ForegroundColor Cyan
cmake --build $buildDir --config Release -j $cores --target llama-server

# ── Flatten to bin\ so the launch script finds it ───────────────────────────
# CMake puts the Release binary in bin\Release\ on Windows; flatten to bin\.
if (Test-Path $serverExe) {
    Write-Host ""
    Write-Host "[compile] Done. llama-server.exe ready at:" -ForegroundColor Green
    Write-Host "  $serverExe" -ForegroundColor Green
} else {
    Write-Host "[compile] Build finished but llama-server.exe not found — check output above for errors." -ForegroundColor Red
    exit 1
}
