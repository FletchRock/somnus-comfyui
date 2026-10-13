# syntax=docker/dockerfile:1.7
# SOMNUS — single-image CUDA 13.0 build.
# Includes ComfyUI, the original pinned custom nodes, CUDA compiler,
# and the original global-storage startup script. No CUDA 12.8 base image.
FROM nvidia/cuda:13.0.3-cudnn-devel-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    MODEL_ROOT=/workspace/models \
    COMFY_PORT=8188 \
    VIRTUAL_ENV=/opt/somnus-venv \
    PATH=/opt/somnus-venv/bin:/usr/local/cuda/bin:${PATH}

# CUDA 13 developer image provides nvcc for custom CUDA kernels.
# Ubuntu 24.04 uses Python 3.12; use a venv to avoid PEP 668 system pip restrictions.
RUN apt-get update && apt-get install -y --no-install-recommends \
      git ffmpeg ca-certificates tini \
      python3 python3-venv python3-dev \
      build-essential cmake ninja-build pkg-config \
      libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 \
    && rm -rf /var/lib/apt/lists/* \
    && python3 -m venv "${VIRTUAL_ENV}" \
    && python -m pip install --no-cache-dir --upgrade pip setuptools wheel

# Install the official CUDA 13.0 PyTorch stack, not CUDA 12.8 wheels.
RUN python -m pip install --no-cache-dir \
      torch==2.9.1 torchvision==0.24.1 torchaudio==2.9.1 \
      --index-url https://download.pytorch.org/whl/cu130

# Retain the exact ComfyUI revision used by the working SOMNUS image.
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /opt/ComfyUI \
    && git -C /opt/ComfyUI checkout e8665ca8

# Retain SOMNUS custom nodes and the previously established commit pins.
RUN set -eu; cd /opt/ComfyUI/custom_nodes; \
    git clone https://github.com/kijai/ComfyUI-KJNodes.git; \
    git -C ComfyUI-KJNodes checkout d764153; \
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git; \
    git -C ComfyUI-Manager checkout 45c3fb68; \
    git clone https://github.com/ethanfel/ComfyUI-MiniMaxH3-Contex-Loop.git; \
    git -C ComfyUI-MiniMaxH3-Contex-Loop checkout fd8d57f; \
    git clone https://github.com/rgthree/rgthree-comfy.git; \
    git -C rgthree-comfy checkout d7297b4; \
    git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git; \
    git clone https://github.com/lihaoyun6/ComfyUI-llama-cpp_vlm.git

RUN set -eu; \
    python -m pip install -r /opt/ComfyUI/requirements.txt; \
    python -m pip install -r /opt/ComfyUI/custom_nodes/ComfyUI-KJNodes/requirements.txt; \
    python -m pip install -r /opt/ComfyUI/custom_nodes/ComfyUI-VideoHelperSuite/requirements.txt; \
    python -m pip install -r /opt/ComfyUI/custom_nodes/ComfyUI-llama-cpp_vlm/requirements.txt; \
    for path in \
      /opt/ComfyUI/custom_nodes/ComfyUI-Manager/requirements.txt \
      /opt/ComfyUI/custom_nodes/rgthree-comfy/requirements.txt; do \
      if [ -f "$path" ]; then python -m pip install -r "$path"; fi; \
    done

# Protect CUDA 13 PyTorch from indirect requirements that might replace it.
RUN python -m pip install --no-cache-dir \
      torch==2.9.1 torchvision==0.24.1 torchaudio==2.9.1 \
      --index-url https://download.pytorch.org/whl/cu130 \
    && python -c 'import torch; print("SOMNUS torch:", torch.__version__, "CUDA:", torch.version.cuda); assert torch.version.cuda == "13.0", "Expected CUDA 13.0 PyTorch"' \
    && nvcc --version

COPY entrypoint.sh /usr/local/bin/somnus-entrypoint
RUN chmod 755 /usr/local/bin/somnus-entrypoint

WORKDIR /opt/ComfyUI
EXPOSE 8188
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/somnus-entrypoint"]
