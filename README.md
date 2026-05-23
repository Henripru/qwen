# Qwen-setup — Quickstart (happy path)

This short guide focuses on the happy path: minimal, copy-and-paste steps to build and run the local server used by this project. It omits advanced git/submodule workflows.

**Assumptions**
- OS: Windows 10/11 with PowerShell available
- You have admin rights to install drivers/toolchains if needed

**1) Prerequisites**
- Git (for cloning)
- Visual Studio Build Tools (C++ workload) or Visual Studio — for MSVC `cl.exe`
- CMake (>= 3.20) and optionally Ninja
- NVIDIA drivers + CUDA Toolkit if you intend to use GPU acceleration
  - Verify GPU/CUDA quickly:
    - `nvidia-smi`
    - `nvcc --version`

**2) Model files (Hugging Face or other source)**
- Obtain the model files you plan to use (e.g. from Hugging Face model page) and place them in a directory on your machine, for example `C:\models\my-model.safetensors`.

**3) Clone and build (happy path)**
- Clone the repo and enter it:
  - `git clone <repo-url> qwen-setup`
  - `cd qwen-setup`

- Recommended: use the included build script to compile the native server binaries:
  - `powershell -ExecutionPolicy Bypass -File .\compile.ps1`

- Manual build (if you prefer to run CMake directly):
  - `cd llama.cpp`
  - `mkdir build && cd build`
  - `cmake -G "Ninja" -DCMAKE_BUILD_TYPE=Release ..`
  - `cmake --build . --config Release -j`

**4) Run the server (set port and model path)**
- Start the server pointing at your model and desired port:
  - `llama-server.exe --model C:\models\my-model.safetensors --port 9000`

- Or use the repository helper:
  - `powershell -ExecutionPolicy Bypass -File .\qwen-moe-turbo.ps1`

- To change the port, pass `--port <PORT>` to the server or edit the script's parameter.

**5) Quick verification**
- Confirm the server binary exists (example path):
  - `Test-Path .\llama.cpp\build\bin\llama-server.exe`
- Curl or browser check (if server exposes HTTP):
  - `curl http://localhost:9000/` or use the client that consumes the server API.

**6) Configure Claude Code to use a local server (brief)**
- The project contains `.claude/settings.local.json` used for local checks and limited automation permissions. If you want Claude to call local checks, ensure `permissions.allow` contains the necessary PowerShell checks (for example `nvidia-smi`, `cmake --version`, and `Test-Path` for the server binary).
- To point Claude at a running local model endpoint, register an `mcpServers` entry in your Claude settings (via the Claude UI `/mcp` flow or by adding the appropriate JSON entry to `.claude/settings.json`).

**7) Troubleshooting (short)**
- Build failures: ensure Visual Studio C++ workload is installed and `cl.exe` is on PATH.
- GPU/CUDA: confirm `nvidia-smi` and `nvcc` are present; otherwise build & run in CPU mode first.

**Happy-path checklist**
1. Install Git, Visual Studio Build Tools, CMake
2. Place model files in `C:\models` or another folder
3. Run `powershell -ExecutionPolicy Bypass -File .\compile.ps1`
4. Start server: `llama-server.exe --model C:\models\my-model.safetensors --port 9000`

If you want, I can now commit this simplified `README.md` for you.

