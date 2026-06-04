# Overview

Use Qwen 3.6 locally using Claude Code.

**Prerequisites**
- Windows 11
- Claude Code
- Visual Studio 2022 (C++ workload)
- CMake
- Python 3.14
- CUDA Toolkit 12.8.2 (Express installation is fine)

**Steps**
- Install Python dependencies (`.\install-dependencies.ps1`)
- Download the model (`.\download.ps1`)
- Compile llama.cpp (`.\compile.ps1`)
- Start llama-server (`.\run.ps1`)
- Run local model
```
$env:ANTHROPIC_BASE_URL          = "http://localhost:11434"
$env:ANTHROPIC_API_KEY           = "local"
$env:CLAUDE_CODE_DISABLE_TELEMETRY = "1"
claude --model Qwen_Qwen3.6-35B-A3B-IQ4_XS
```
