#!/usr/bin/env bash
set -euo pipefail

# SOMNUS Creative Studio: ComfyUI installed in image, models and assets on RunPod Global Volume.
MODEL_ROOT="${MODEL_ROOT:-/workspace/models}"
if [[ ! -d "$MODEL_ROOT/diffusion_models" ]]; then
  if [[ -d /workspace/models/diffusion_models ]]; then
    MODEL_ROOT=/workspace/models
  elif [[ -d /workspace-global/models/diffusion_models ]]; then
    MODEL_ROOT=/workspace-global/models
  else
    echo 'ERROR: Global Volume model library not found.' >&2
    exit 1
  fi
fi
STORAGE_ROOT="${STORAGE_ROOT:-$(dirname "$MODEL_ROOT")/somnus-data}"

# These directories are supplied directly to ComfyUI, so files survive Pod termination.
mkdir -p "$STORAGE_ROOT/input" "$STORAGE_ROOT/output" "$STORAGE_ROOT/user/default"

# Save ComfyUI default-profile settings and workflows persistently. The main user
# directory stays local: it contains a live SQLite DB, locks and caches.
mkdir -p /opt/ComfyUI/user
LOCAL_DEFAULT=/opt/ComfyUI/user/default
if [[ ! -L "$LOCAL_DEFAULT" ]]; then
  if [[ -d "$LOCAL_DEFAULT" ]]; then
    cp -R -n "$LOCAL_DEFAULT"/. "$STORAGE_ROOT/user/default/" 2>/dev/null || true
    mv "$LOCAL_DEFAULT" "${LOCAL_DEFAULT}.image-original"
  fi
  ln -s "$STORAGE_ROOT/user/default" "$LOCAL_DEFAULT"
fi

# Restore the previously snapshotted SQLite database locally, never run it on
# network storage. This snapshot is not automatically updated during a session.
if [[ -f "$STORAGE_ROOT/comfyui-db-backup.db" && ! -f /opt/ComfyUI/user/comfyui.db ]]; then
  cp "$STORAGE_ROOT/comfyui-db-backup.db" /opt/ComfyUI/user/comfyui.db
fi

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

echo "SOMNUS: models=$MODEL_ROOT; persistent assets=$STORAGE_ROOT; port=${COMFY_PORT:-8188}"
cd /opt/ComfyUI
exec python main.py \
  --listen 0.0.0.0 \
  --port "${COMFY_PORT:-8188}" \
  --input-directory "$STORAGE_ROOT/input" \
  --output-directory "$STORAGE_ROOT/output" \
  "$@"
