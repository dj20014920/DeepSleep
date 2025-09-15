#!/bin/zsh
set -euo pipefail
mkdir -p models out
if command -v hf >/dev/null 2>&1; then :; else
  python3 -m pip install --upgrade pip
  python3 -m pip install "huggingface_hub[cli]"
fi
hf download unsloth/gemma-3-270m-it-GGUF --include "gemma-3-270m-it-Q8_0.gguf" --local-dir "models"
hf download Qwen/Qwen2.5-0.5B-Instruct-GGUF --include "qwen2.5-0.5b-instruct-q4_k_m.gguf" --local-dir "models"
hf download bartowski/google_gemma-3-1b-it-GGUF --include "google_gemma-3-1b-it-IQ4_XS.gguf" --local-dir "models"
shasum -a 256 models/*.gguf | tee out/sha256sum.txt
SUBCMD=""
if xcrun backgroundassets pack --help >/dev/null 2>&1; then
  SUBCMD="pack"
elif xcrun backgroundassets package --help >/devnull 2>&1; then
  SUBCMD="package"
else
  echo "missing backgroundassets"
  exit 2
fi
make_one() {
  mani="$1"
  outpath="$2"
  if [[ "$SUBCMD" == "pack" ]]; then
    xcrun backgroundassets pack --manifest "$mani" --output "$outpath"
  else
    xcrun backgroundassets package --manifest "$mani" --out "$outpath"
  fi
  unzip -l "$outpath" | sed -n '1,50p'
}
make_one "manifests/gemma270.json" "out/pack.model.gemma270.q8.aar"
make_one "manifests/qwen05b.json" "out/pack.model.qwen05b.q4.aar"
make_one "manifests/gemma1b.json" "out/pack.model.gemma1b.iq4.aar"
ls -lh out/*.aar out/sha256sum.txt
