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
- (Optional) Create a [Hugging Face](https://huggingface.co) account, generate an access token, and set `$env:HF_TOKEN="<your_token>"` for faster downloads
- Download the model (`.\download.ps1`)
- Compile llama.cpp (`.\compile.ps1`)
- Start llama-server (`.\run.ps1`)
- Set the permanent PowerShell tool environment variable (`.\setup.ps1`)
- Run local model (`.\qwen.ps1`)
