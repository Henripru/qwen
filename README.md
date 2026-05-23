# Overview

Use Qwen 3.6 locally using Claude Code.

**Prerequisites**
- Windows 11
- Claude Code
- Visual Studio 2022 (C++ workload)
- CMake
- Python 3.14
- CUDA Toolkit 12.8.2 (Express installation is fine)
- Qwen_Qwen3.6-35B-A3B-GGUF
```
py -c "
from huggingface_hub import snapshot_download
snapshot_download(
    repo_id='bartowski/Qwen_Qwen3.6-35B-A3B-GGUF',
    allow_patterns='*IQ4_XS*',
    local_dir=r'C:\Users\henri\models',
    local_dir_use_symlinks=False
)
print('Download complete.')
"
```


**Steps**
- Compile llama.cpp (`./compile.ps1`)
- Restart terminal
- Set environment variables
```
$env:ANTHROPIC_BASE_URL          = "http://localhost:11434"
$env:ANTHROPIC_API_KEY           = "local"
$env:CLAUDE_CODE_DISABLE_TELEMETRY = "1"
```
- Start llama-server (`.\qwen-moe-turbo.ps1 -Port 11434`)
- Run local model (`claude --model Qwen_Qwen3.6-35B-A3B-IQ4_XS`)
