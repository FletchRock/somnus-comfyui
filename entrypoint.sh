#!/usr/bin/env bash
set -euo pipefail

# Support the established /workspace mount and the earlier /workspace-global mount.
if [[ -z "${MODEL_ROOT:-}" ]]; then
  MODEL_ROOT=/workspace/models
fi
if [[ ! -d "$MODEL_ROOT/diffusion_models" ]]; then
  if [[ -d /workspace/models/diffusion_models ]]; then
    MODEL_ROOT=/workspace/models
  elif [[ -d /workspace-global/models/diffusion_models ]]; then
    MODEL_ROOT=/workspace-global/models
  else
    echo "ERROR: Cannot find Global Volume model library." >&2
    echo "Mount the existing volume at /workspace or /workspace-global, or set MODEL_ROOT." >&2
    exit 1
  fi
fi

# Explicit mapping avoids dependency on prior Pods' startup arguments.
cat > /opt/ComfyUI/extra_model_paths.yaml <<YAML
somnus_global:
    base_path: ${MODEL_ROOT}
    diffusion_models: diffusion_models
    text_encoders: text_encoders
    vae: vae
    loras: loras
    checkpoints: checkpoints
    clip_vision: clip_vision
    upscale_models: upscale_models
    latent_upscale_models: latent_upscale_models
    audio_encoders: audio_encoders
YAML

echo "SOMNUS: models from ${MODEL_ROOT}; ComfyUI on port ${COMFY_PORT:-8188}"
cd /opt/ComfyUI
exec python main.py --listen 0.0.0.0 --port "${COMFY_PORT:-8188}" "$@"
