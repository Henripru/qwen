# compile.ps1 — Build llama.cpp for RTX 4500 Ada Generation (Ada Lovelace SM_89)
# Source: shared root-level llama.cpp submodule
# Output: .\build\bin\Release\llama-server.exe (isolated from other GPU builds)
#
# Requirements: CUDA Toolkit 12.x, Visual Studio 2022, CMake, Git
# Run once; re-run to rebuild after updates.

$ErrorActionPreference = "Stop"

$root      = $PSScriptRoot
$srcDir    = Join-Path $root ".." "llama.cpp"
$buildDir  = Join-Path $root "build"
$serverExe = Join-Path $buildDir "bin\Release\llama-server.exe"

# ── Verify CUDA 12.x is on PATH ──────────────────────────────────────────────
$nvcc = Get-Command nvcc -ErrorAction SilentlyContinue
if (-not $nvcc) {
    Write-Host "[compile] nvcc not found — install CUDA Toolkit 12.x from developer.nvidia.com/cuda-toolkit-archive" -ForegroundColor Red
    exit 1
}
$cudaVer = (nvcc --version 2>&1 | Select-String "release (\d+\.\d+)" | ForEach-Object { $_.Matches[0].Groups[1].Value })
Write-Host "[compile] CUDA $cudaVer detected" -ForegroundColor Cyan
if ($cudaVer -and [version]$cudaVer -lt [version]"12.0") {
    Write-Host "[compile] WARNING: CUDA 12.x or newer recommended for Ada Lovelace (SM_89). Please upgrade." -ForegroundColor Yellow
}

# ── Ensure submodule is initialised ──────────────────────────────────────────
Write-Host "[compile] Updating llama.cpp submodule..." -ForegroundColor Cyan
git -C (Join-Path $root "..") submodule update --init --recursive

# ── CMake configure ──────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[compile] Configuring (Ada Lovelace SM_89, CUDA, Flash Attention for all quants)..." -ForegroundColor Cyan
cmake -S $srcDir -B $buildDir `
    -DGGML_CUDA=ON `
    -DCMAKE_CUDA_ARCHITECTURES=89 `
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
