$ErrorActionPreference = "Stop"

$dest = Join-Path $PSScriptRoot "models\Qwen_Qwen3.6-35B-A3B-GGUF"

py -c "
from huggingface_hub import snapshot_download
snapshot_download(
    repo_id='bartowski/Qwen_Qwen3.6-35B-A3B-GGUF',
    allow_patterns='*IQ4_XS*',
    local_dir=r'$dest',
    local_dir_use_symlinks=False
)
print('Download complete.')
"
