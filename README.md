# Qwen-setup — Machine replication notes

This document collects the commands and steps used to reproduce the local development environment used in this project.

**Assumptions**
- OS: Windows 10/11 (PowerShell used in scripts)
- You have administrative rights to install drivers / toolkits

**1) System prerequisites**
- Install Git and configure your user name/email.
- Install Visual Studio Build Tools (C++ workload) or Visual Studio (required for MSVC toolchain).
- Install CMake (>= 3.20) and optionally Ninja.
- NVIDIA drivers + CUDA Toolkit (if you plan to use GPU/OpenCL backends).
  - Verify: `nvcc --version` and `nvidia-smi`
- Python 3.10+ and pip
  - Verify: `python -V` and `pip -V`

**2) Hugging Face / model artifacts**
- Install HF CLI and Python packages used for model download/formatting:
  - `pip install --upgrade pip`
  - `pip install huggingface-hub transformers accelerate safetensors`
- Login to Hugging Face (if needed): `huggingface-cli login`

**3) Clone repo and submodule notes**
- This repository uses `llama.cpp` as a submodule. If you clone afresh:
  - `git clone <repo-url> qwen-setup`
  - `cd qwen-setup`
  - `git submodule update --init --recursive`

If you already cloned and built locally (and want to preserve build outputs) follow the approach used here: keep the local `llama.cpp` working tree in place, add a `.gitmodules` entry and register the submodule SHA in the parent repo before committing. (The project already contains `.gitmodules` and the submodule is pinned to a commit.)

**4) Build (compile) steps**
- There are helper PowerShell scripts in the repo:
  - `compile.ps1` — runs the local build for the project
  - `qwen-moe-turbo.ps1` — helper to start the qwen server wrapper

- To run the compile script from PowerShell (recommended):
  - `powershell -ExecutionPolicy Bypass -File .\compile.ps1`

If you prefer to build `llama.cpp` manually (MSVC/Ninja example):
  - `cd llama.cpp`
  - `mkdir build && cd build`
  - `cmake -G "Ninja" -DCMAKE_BUILD_TYPE=Release ..`
  - `cmake --build . --config Release -j` 

On success the server binary is typically at `llama.cpp\build\bin\llama-server.exe` (or similar path in `build/bin`).

**5) Start the qwen / llama server and port config**
- Example command to start the server (adjust model path and port):
  - `llama-server.exe --model C:\path\to\model.safetensors --port 9000`
- Or use the included helper (PowerShell):
  - `powershell -ExecutionPolicy Bypass -File .\qwen-moe-turbo.ps1` 
  - The script accepts options — open it to see flags for `--port` or `--model`.
- To change the listening port, pass `--port <PORT>` to the server or edit the script to set the desired port.

**6) Verify GPU / OpenCL availability**
- `nvidia-smi` — verifies driver and GPU presence
- `nvcc --version` — verifies CUDA installation
- `cmake --version` — verifies CMake

**7) Configure Claude (Claude Code) to use a local model / local server**
- Claude Code supports MCP servers and local tool calls. Project-level overrides are stored at `.claude/settings.local.json` (this repo contains a permissions allowlist used for automation checks).
- To let Claude call local PowerShell checks and the local server, add or update the project `.claude/settings.local.json` with entries under `permissions.allow`. Example (already present in this project):
  - `PowerShell(nvcc --version 2>&1)`
  - `PowerShell(cmake --version 2>&1)`
  - `PowerShell(nvidia-smi 2>&1)`
  - `PowerShell(Test-Path build\\bin\\llama-server.exe)`
- To register a local model endpoint as an MCP server in Claude Code you can add an `mcpServers` entry in your global or project `.claude/settings.json` / `settings.local.json` telling Claude how to call it. The exact format depends on your Claude installation; typical items include `name`, `url`, `auth` type and allowed scopes. (If you use Claude MCP connectors, add them via the Claude UI `/mcp` flow; for file-based configuration add the matching JSON object to `.claude/settings.json`.)

**8) Common troubleshooting**
- If build fails, check the Visual Studio C++ workload and that `cl.exe` is on PATH.
- If CUDA/OpenCL features are desired but not required, try building without GPU acceleration first.
- If `llama.cpp` shows up as tracked files in `git status` and you want to keep your local build but not commit it:
  - `git rm --cached llama.cpp`
  - Add `llama.cpp/` to `.gitignore` (or configure as a proper submodule with `.gitmodules` and `git submodule add`).

**9) Repro checklist for a fresh machine**
1. Install Git, Visual Studio Build Tools, CMake, Python
2. Install NVIDIA drivers + CUDA Toolkit (if using GPU)
3. Clone repo and run `git submodule update --init --recursive`
4. Install Python deps and Hugging Face CLI: `pip install huggingface-hub transformers accelerate safetensors`
5. Run `powershell -ExecutionPolicy Bypass -File .\compile.ps1`
6. Start server: `powershell -ExecutionPolicy Bypass -File .\qwen-moe-turbo.ps1` or run `llama-server.exe --port <PORT>`

If you want I can: commit the staged `.gitmodules` and `.gitignore` changes, or produce a more detailed step-by-step that includes exact download URLs and Visual Studio/CUDA installer options.

---
Generated from project transcripts and local setup notes.
