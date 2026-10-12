# syntax=docker/dockerfile:1.7
# Matches the RunPod PyTorch/CUDA environment used for the working SOMNUS Pod.
FROM runpod/pytorch:1.0.2-cu1281-torch280-ubuntu2404

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    MODEL_ROOT=/workspace/models \
    COMFY_PORT=8188

RUN apt-get update && apt-get install -y --no-install-recommends \
      git ffmpeg ca-certificates tini \
    && rm -rf /var/lib/apt/lists/*

# Reproduce the exact ComfyUI commit observed on the original working Pod.
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /opt/ComfyUI \
    && cd /opt/ComfyUI && git checkout e8665ca8

# Pin custom nodes to commits taken directly from the working Pod.
RUN set -eu; cd /opt/ComfyUI/custom_nodes; \
    git clone https://github.com/kijai/ComfyUI-KJNodes.git; \
    git -C ComfyUI-KJNodes checkout d764153; \
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git; \
    git -C ComfyUI-Manager checkout 45c3fb68; \
    git clone https://github.com/ethanfel/ComfyUI-MiniMaxH3-Contex-Loop.git; \
    git -C ComfyUI-MiniMaxH3-Contex-Loop checkout fd8d57f; \
    git clone https://github.com/rgthree/rgthree-comfy.git; \
    git -C rgthree-comfy checkout d7297b4

# Build the Python environment into the image, never onto Global Storage.
RUN set -eu; \
    python -m pip install -r /opt/ComfyUI/requirements.txt; \
    python -m pip install -r /opt/ComfyUI/custom_nodes/ComfyUI-KJNodes/requirements.txt; \
    for path in \
      /opt/ComfyUI/custom_nodes/ComfyUI-Manager/requirements.txt \
      /opt/ComfyUI/custom_nodes/rgthree-comfy/requirements.txt; do \
      if [ -f "$path" ]; then python -m pip install -r "$path"; fi; \
    done; \
    python -c 'import torch; assert torch.cuda.is_available() or torch.version.cuda is not None; print("Torch", torch.__version__, "CUDA", torch.version.cuda)'

COPY entrypoint.sh /usr/local/bin/somnus-entrypoint
RUN chmod 755 /usr/local/bin/somnus-entrypoint

WORKDIR /opt/ComfyUI
EXPOSE 8188
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/somnus-entrypoint"]
