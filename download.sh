#!/usr/bin/env bash

set -e

BASE_PATH="/workspace/ComfyUI/models"
DOWNLOAD_LIST="download.txt"
FAILED_LIST="failed_downloads.txt"

mkdir -p "$BASE_PATH/checkpoints" "$BASE_PATH/vae" "$BASE_PATH/loras" "$BASE_PATH/controlnet" "$BASE_PATH/diffusion_models"

> "$FAILED_LIST"

download_single() {
  local folder_type=$1
  local url=$2

  case "$folder_type" in
    vae) target_dir="$BASE_PATH/vae" ;;
    checkpoints) target_dir="$BASE_PATH/checkpoints" ;;
    loras) target_dir="$BASE_PATH/loras" ;;
    controlnet) target_dir="$BASE_PATH/controlnet" ;;
    diffusion_models) target_dir="$BASE_PATH/diffusion_models" ;;
    *)
      echo "Unknown folder type: $folder_type"
      return 0
      ;;
  esac

  mkdir -p "$target_dir"
  filename=$(basename "$url")

  if [ ! -f "$target_dir/$filename" ]; then
    echo "Downloading $filename to $target_dir"
    if wget --continue --tries=3 --timeout=30 -O "$target_dir/$filename" "$url"; then
      if [ -s "$target_dir/$filename" ]; then
        echo "Download successful: $filename"
      else
        echo "Download failed (empty file): $filename"
        echo "$folder_type,$url" >> "$FAILED_LIST"
        rm -f "$target_dir/$filename"
      fi
    else
      echo "Download failed: $url"
      echo "$folder_type,$url" >> "$FAILED_LIST"
      rm -f "$target_dir/$filename"
    fi
  else
    echo "$filename already exists in $target_dir, skipping."
  fi
}

export -f download_single
export BASE_PATH
export FAILED_LIST

# Download all models (parallel 4 at a time)
cat "$DOWNLOAD_LIST" | grep -v '^#' | grep -v '^$' | xargs -n1 -P4 bash -c '
  folder_type=$(echo "$0" | cut -d"," -f1)
  url=$(echo "$0" | cut -d"," -f2-)
  download_single "$folder_type" "$url"
'

# Retry failed downloads once
if [ -s "$FAILED_LIST" ]; then
  echo "Retrying failed downloads..."
  mv "$FAILED_LIST" temp_failed.txt
  > "$FAILED_LIST"

  cat temp_failed.txt | xargs -n1 -P4 bash -c '
    folder_type=$(echo "$0" | cut -d"," -f1)
    url=$(echo "$0" | cut -d"," -f2-)
    download_single "$folder_type" "$url"
  '
fi

echo "All downloads completed."