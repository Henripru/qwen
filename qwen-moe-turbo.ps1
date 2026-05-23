param(
    # Optional explicit override. If empty, shows interactive picker scanning HF cache.
    [string]$Model = "",

    # Context budget. Bench-validated max on 16 GB at ub=512 + ncmoe=4: see notes below.
    # If you OOM at deep context, raise -NCpuMoe.
    [int]$Context = 196608,

    [int]$ReasoningBudget = 8192,

    # Reasoning ON by default. Pass -ReasoningOff to disable on a per-launch basis.
    [switch]$ReasoningOff,

    [int]$Port = 8080
)

$ErrorActionPreference = "Stop"

$llama = Join-Path $PSScriptRoot "build\bin\Release\llama-server.exe"
if (-not (Test-Path $llama)) {
    Write-Host "[qwen-moe-turbo] llama-server.exe not built. Run: compile.ps1" -ForegroundColor Red
    exit 1
}

# ----------------------------------------------------------------------
# Model picker — scans ~\models recursively for .gguf files.
# Each subfolder may contain one main model + optional mmproj.gguf
# (vision projector). When a model is picked, the launcher auto-links
# any mmproj sibling found in the same folder via --mmproj.
# ----------------------------------------------------------------------
$mmproj = ""
if (-not $Model) {
    $modelsDir = Join-Path $env:USERPROFILE "models"
    if (-not (Test-Path $modelsDir)) {
        Write-Host "[qwen-moe-turbo] models folder not found at $modelsDir - creating it" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $modelsDir -Force | Out-Null
    }

    # Recursive scan; treat any .gguf whose name contains "mmproj" as a projector,
    # not a selectable model.
    $allGgufs = Get-ChildItem -Path $modelsDir -Filter "*.gguf" -File -Recurse -ErrorAction SilentlyContinue
    $ggufs = $allGgufs | Where-Object { $_.Name -notmatch '(?i)mmproj' } | Sort-Object Length

    if ($ggufs.Count -eq 0) {
        Write-Host "[qwen-moe-turbo] No model .gguf files found in $modelsDir (or its subfolders)" -ForegroundColor Red
        Write-Host "Drop .gguf files into that folder (or subfolders) and rerun." -ForegroundColor Yellow
        exit 1
    }

    # Single match -> skip picker
    if ($ggufs.Count -eq 1) {
        $Model = $ggufs[0].FullName
        Write-Host "[qwen-moe-turbo] Auto-selected only available model: $($ggufs[0].Name)" -ForegroundColor Cyan
    } else {
        # Pre-compute display rows; show folder name + filename + size
        $rows = @()
        for ($i = 0; $i -lt $ggufs.Count; $i++) {
            $sizeGB = [math]::Round($ggufs[$i].Length / 1GB, 2)
            $folder = Split-Path $ggufs[$i].DirectoryName -Leaf
            # Detect any mmproj sibling for this gguf's directory
            $hasMmproj = ($allGgufs | Where-Object {
                $_.DirectoryName -eq $ggufs[$i].DirectoryName -and $_.Name -match '(?i)mmproj'
            } | Select-Object -First 1) -ne $null
            $tag = if ($hasMmproj) { " [+vision]" } else { "" }
            $rows += [PSCustomObject]@{
                Line1 = ("{0,6:N2} GB  {1}{2}" -f $sizeGB, $ggufs[$i].Name, $tag)
                Line2 = "  in $folder/"
            }
        }

        Write-Host ""
        Write-Host "Available GGUFs in ${modelsDir}:" -ForegroundColor Cyan
        Write-Host ""

        $selected = 0
        $count = $rows.Count
        [Console]::CursorVisible = $false
        $startTop = [Console]::CursorTop

        try {
            while ($true) {
                [Console]::SetCursorPosition(0, $startTop)
                for ($i = 0; $i -lt $count; $i++) {
                    $marker = if ($i -eq $selected) { ">" } else { " " }
                    $col1   = if ($i -eq $selected) { "Yellow" }    else { "White" }
                    $col2   = if ($i -eq $selected) { "DarkYellow" } else { "DarkGray" }
                    $line1 = "{0} {1,2}  {2}" -f $marker, $i, $rows[$i].Line1
                    $line2 = "      {0}" -f $rows[$i].Line2
                    # Pad to clear any leftover characters from previous longer rows
                    Write-Host ($line1.PadRight([Console]::WindowWidth - 1)) -ForegroundColor $col1
                    Write-Host ($line2.PadRight([Console]::WindowWidth - 1)) -ForegroundColor $col2
                }
                Write-Host ""
                Write-Host (("  up/down navigate  |  Enter select  |  Esc cancel  |  digit jumps").PadRight([Console]::WindowWidth - 1)) -ForegroundColor DarkGray

                $key = [Console]::ReadKey($true)
                switch ($key.Key) {
                    'UpArrow'   { if ($selected -gt 0)        { $selected-- } }
                    'DownArrow' { if ($selected -lt $count-1) { $selected++ } }
                    'Home'      { $selected = 0 }
                    'End'       { $selected = $count - 1 }
                    'Enter'     {
                        [Console]::CursorVisible = $true
                        $Model = $ggufs[$selected].FullName
                        Write-Host ""
                        break
                    }
                    'Escape'    {
                        [Console]::CursorVisible = $true
                        Write-Host ""
                        Write-Host "[qwen-moe-turbo] cancelled" -ForegroundColor Yellow
                        exit 1
                    }
                    default {
                        if ($key.KeyChar -match '^\d$') {
                            $n = [int]$key.KeyChar.ToString()
                            if ($n -lt $count) { $selected = $n }
                        }
                    }
                }
                if ($key.Key -eq 'Enter') { break }
            }
        } finally {
            [Console]::CursorVisible = $true
        }
    }
}

if (-not (Test-Path $Model)) {
    Write-Host "[qwen-moe-turbo] model not found: $Model" -ForegroundColor Red
    exit 1
}

# ----------------------------------------------------------------------
# Detect mmproj (vision projector) in the model's directory.
# Any .gguf with "mmproj" in the name (case-insensitive) qualifies.
# ----------------------------------------------------------------------
$modelDir = Split-Path $Model -Parent
$mmprojCandidate = Get-ChildItem -Path $modelDir -Filter "*.gguf" -File -ErrorAction SilentlyContinue |
                   Where-Object { $_.Name -match '(?i)mmproj' } |
                   Select-Object -First 1
if ($mmprojCandidate) {
    $mmproj = $mmprojCandidate.FullName
    Write-Host "[qwen-moe-turbo] vision mmproj detected: $($mmprojCandidate.Name)" -ForegroundColor Cyan
}

# ----------------------------------------------------------------------
# Reasoning ON by default; override with -ReasoningOff
# ----------------------------------------------------------------------
$reasoningEnabled = -not $ReasoningOff
$reasoningArg = if ($reasoningEnabled) { "on" } else { "off" }
$mode = if ($reasoningEnabled) { "reasoning ON" } else { "reasoning OFF" }

# Chat-template kwargs — keep simple, let llama.cpp's --reasoning flag
# handle the on/off semantics. Layering enable_thinking + budget=0 on
# top caused weirdness during testing; the --reasoning flag alone is
# what's bench-validated.
$chatKwargs = '{"preserve_thinking": true}'
$effectiveBudget = $ReasoningBudget

# ----------------------------------------------------------------------
# Sampler defaults — empirically validated config (fork qwen-turbo.ps1 path):
#   Coding (reasoning ON): 11/11 EventBus, 12/12 TaskScheduler at these params
# Qwen3 model card suggested presence=0.0 for coding, but the fork's
# presence=1.5 outperformed that on real coding harnesses; trusting the
# empirical result over the card recommendation.
# ----------------------------------------------------------------------
if ($reasoningEnabled) {
    $temp = 0.6; $topP = 0.95; $topK = 20; $presencePenalty = 1.5
} else {
    $temp = 0.7; $topP = 0.80; $topK = 20; $presencePenalty = 1.5
}

$env:LLAMA_ARG_KV_UNIFIED        = "1"
$env:LLAMA_ARG_CACHE_IDLE_SLOTS  = "1"

$modelName = [System.IO.Path]::GetFileNameWithoutExtension($Model)
Write-Host ""
Write-Host "[qwen-moe-turbo] $modelName" -ForegroundColor Cyan
Write-Host "  ctx=$Context (fit-ctx 65536), ub=512, ctk/v=q8_0, $mode" -ForegroundColor Gray
Write-Host ""

# ============================================================================
# Bench-validated config for RTX 5080 16GB + Qwen3.6-35B-A3B (mainline b8967)
#
# Validated A/B (server print_timing eval time on bill-splitter prompt):
#   default mainline:    63.0 t/s   (--fit-ctx 196608, ub=1024)
#   --fit-ctx 65536:     68.1 t/s   (+8% — smaller compute graph)
#   + ub=512:            78.9 t/s   (+25% over default)
#   + ctk/ctv q8_0:      pending     (~1.9 GB KV freed; expected ~+10-15%)
#   + spec ngram-mod:    77.7 t/s   (-1.6%; ngram cache kept resetting)
#
# Sampler params from Qwen3.6-A3B model card recommendations:
#   - thinking + precise coding: temp=0.6 top_p=0.95 top_k=20 presence=0.0
#   - non-thinking + general:    temp=0.7 top_p=0.80 top_k=20 presence=1.5
#
# Other knobs returned to mainline defaults (no measured benefit):
#   --fit-target (was 32, default 1024 — more allocator headroom)
#   --prio (was 2, default 0)
#   --poll (was 100, default 50)
#   removed --repeat-penalty 1.00 (no-op math), --min-p 0.0 (no-op default),
#   --reasoning-budget-message (default suffices)
#
# Kept non-default but useful:
#   --no-mmap (full RAM load; faster repeat starts)
#
# DO NOT add: --spec-type (neutral-to-negative on this model),
# --cache-type-k turbo3_tcq (beaten by f16 on Blackwell).
# ============================================================================

$mmprojArgs = if ($mmproj) { @("--mmproj", $mmproj) } else { @() }
$alias = [System.IO.Path]::GetFileNameWithoutExtension($Model)

# ----------------------------------------------------------------------
# Adaptive fit-target by model size (16 GB VRAM card).
# Bigger models leave less GPU headroom → need more reserve for runtime
# allocator spikes (CUDA caching alloc, KV growth past fit-ctx, graph
# captures). Tiers calibrated for Qwen3.6-A3B family on RTX 5080:
#   < 14 GB (Mini): margin 128 MiB    — plenty of GPU room, pack tight
#   14-18 GB (Compact/I-Compact): 256 MiB — current default, validated
#   18-22 GB (Quality/I-Quality): 512 MiB — needs more allocator buffer
#   > 22 GB (Balanced/I-Balanced/Q4_K_XL): 1024 MiB — heavy host offload,
#                                                     don't squeeze GPU
# Override with -FitTarget N if needed.
# ----------------------------------------------------------------------
$modelSizeGB = (Get-Item $Model).Length / 1GB
$fitTarget = if ($modelSizeGB -lt 14)      { 128 }
             elseif ($modelSizeGB -lt 18)  { 256 }
             elseif ($modelSizeGB -lt 22)  { 512 }
             else                          { 1024 }
Write-Host "[qwen-moe-turbo] model $([math]::Round($modelSizeGB,2)) GB -> --fit-target $fitTarget MiB" -ForegroundColor Gray

& $llama `
  -m $Model `
  @mmprojArgs `
  --alias $alias `
  --host 0.0.0.0 --port $Port `
  --fit on --fit-target $fitTarget --fit-ctx 65536 `
  -c $Context `
  --parallel 1 `
  --flash-attn on `
  --batch-size 2048 --ubatch-size 512 `
  --threads 12 --threads-batch 12 `
  -ctk q8_0 -ctv q8_0 `
  --cache-ram -1 `
  --checkpoint-every-n-tokens 32768 `
  --prio 2 --prio-batch 2 `
  --poll 100 `
  --no-mmap `
  --jinja `
  --reasoning $reasoningArg `
  --reasoning-budget $effectiveBudget `
  --reasoning-budget-message "Time to wrap up. Let me give my answer." `
  --presence-penalty $presencePenalty `
  --repeat-penalty 1.00 `
  --chat-template-kwargs $chatKwargs `
  --temp $temp --top-p $topP --top-k $topK --min-p 0.0
