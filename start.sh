#!/usr/bin/env bash

set -e  # stop script if any command fails

# Optional: Use better memory management if available
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
if [ -n "$TCMALLOC" ]; then
  export LD_PRELOAD="${TCMALLOC}"
fi

# Define workspace
NETWORK_VOLUME="/workspace"

# Install Python libraries
echo "Installing Python libraries..."
pip install --upgrade pip
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
pip install diffusers transformers accelerate scipy safetensors jupyterlab

# Clone ComfyUI if not exists
if [ ! -d "$NETWORK_VOLUME/ComfyUI" ]; then
  echo "Cloning ComfyUI..."
  git clone https://github.com/comfyanonymous/ComfyUI.git "$NETWORK_VOLUME/ComfyUI"
fi

# Install ComfyUI dependencies
echo "Installing ComfyUI requirements..."
pip install -r "$NETWORK_VOLUME/ComfyUI/requirements.txt"

# Create models folder if missing
mkdir -p "$NETWORK_VOLUME/ComfyUI/models/checkpoints"
mkdir -p "$NETWORK_VOLUME/ComfyUI/models/vae"
mkdir -p "$NETWORK_VOLUME/ComfyUI/models/loras"
mkdir -p "$NETWORK_VOLUME/ComfyUI/models/controlnet"

# Start JupyterLab in background
echo "Starting JupyterLab..."
jupyter lab --ip=0.0.0.0 --port=8888 --allow-root --no-browser --NotebookApp.token='' --NotebookApp.password='' --ServerApp.allow_origin='*' --ServerApp.allow_credentials=True --notebook-dir="$NETWORK_VOLUME" &

sleep 5  # Give Jupyter a moment to initialize

# Start ComfyUI
echo "Starting ComfyUI..."
cd "$NETWORK_VOLUME/ComfyUI"
ALLOW_UNSAFE_MODEL_LOADING=1 python3 main.py --listen 0.0.0.0 --port 8188
