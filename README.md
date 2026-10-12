# SOMNUS ComfyUI / RunPod

A pinned ComfyUI + H3 Contex Loop container for RunPod Pods with an existing **Global Network Volume** containing models.

## Build

On GitHub, push the Dockerfile, entrypoint.sh and `.github/workflows/build.yml` to `main`. Go to **Actions → Build and publish SOMNUS → Run workflow** (or let the push trigger it). The workflow attempts to publish:

`ghcr.io/fletchrock/somnus-comfyui:latest`

See the Actions log for build/push success. This is an untested first build; dependency or hosted-runner disk issues may need adjustments.

## RunPod

After the image is successfully published, make the GHCR package **public** (if not already public) at GitHub Packages, or configure authentication. Use image `ghcr.io/fletchrock/somnus-comfyui:latest` as the Docker image of a new RunPod Pod/template. Expose HTTP port **8188**. Attach the existing Global Network Volume at `/workspace`, where models are expected under `/workspace/models`. The launcher also detects `/workspace-global/models`.

ComfyUI runs from **/opt/ComfyUI** inside the image, not Global Storage. Do not overwrite /opt/ComfyUI by mounting the volume there.

Important: RunPod must be configured to use the image's entrypoint (do not set a conflicting Docker command). The image expects normal NVIDIA GPU runtime and CUDA driver support. Saved workflows, inputs and outputs under /opt/ComfyUI are ephemeral; move valuable outputs to the Global Volume or configure persistent folders before terminating a Pod.

## Pins from the October 2026 working environment

- ComfyUI: `e8665ca8`
- KJNodes: `d764153`
- ComfyUI-Manager: `45c3fb68`
- H3 Contex Loop: `fd8d57f`
- rgthree-comfy: `d7297b4`

The `minimax-h3-comfyui` example-workflows repository was deliberately **not** added as a custom node, because it lacks `__init__.py` and failed to import in the previous Pod.

## Scope

This reproduces the **four confirmed custom node repositories**, not necessarily every dependency required by every future H3 workflow. Check missing nodes and model compatibility using an actual workflow test. The original backup remains at `/workspace/somnus-backup/` on the Global Volume.
