#!/bin/zsh
set -euo pipefail

REPO_ROOT="$(pwd)"
mkdir -p "${REPO_ROOT}/models" "${REPO_ROOT}/out" "${REPO_ROOT}/tmp"

# 1) 모델 다운로드(이미 있으면 스킵)
if [[ ! -f "${REPO_ROOT}/models/gemma-3-270m-it-Q8_0.gguf" ]]; then
  hf download unsloth/gemma-3-270m-it-GGUF --include "gemma-3-270m-it-Q8_0.gguf" --local-dir "${REPO_ROOT}/models"
fi
if [[ ! -f "${REPO_ROOT}/models/qwen2.5-0.5b-instruct-q4_k_m.gguf" ]]; then
  hf download Qwen/Qwen2.5-0.5B-Instruct-GGUF --include "qwen2.5-0.5b-instruct-q4_k_m.gguf" --local-dir "${REPO_ROOT}/models"
fi
if [[ ! -f "${REPO_ROOT}/models/google_gemma-3-1b-it-IQ4_XS.gguf" ]]; then
  hf download bartowski/google_gemma-3-1b-it-GGUF --include "google_gemma-3-1b-it-IQ4_XS.gguf" --local-dir "${REPO_ROOT}/models"
fi

# 2) sha256 기록
shasum -a 256 "${REPO_ROOT}/models/"*.gguf | tee "${REPO_ROOT}/out/sha256sum.txt"

# 3) 수동 패킹 함수 (zip -0: 무압축, -X: 확장속성 제거)
pack_one () {
  local pack_id="$1"
  local src_path="$2"
  local dest_name="$3"

  local workdir="${REPO_ROOT}/tmp/${pack_id}"
  local out_aar="${REPO_ROOT}/out/${pack_id}.aar"
  rm -rf "$workdir" "$out_aar"
  mkdir -p "$workdir"

  # manifest.json
  cat > "${workdir}/manifest.json" <<JSON
{
  "id": "${pack_id}",
  "resources": [
    { "source": "${dest_name}", "destination": "${dest_name}", "compression": "none" }
  ]
}
JSON

  cp -f "$src_path" "${workdir}/${dest_name}"

  # zip을 out_aar로 직접 생성 (절대경로)
  /usr/bin/zip -0 -X "$out_aar" -j "${workdir}/manifest.json" "${workdir}/${dest_name}"

  # 내용 미리보기
  /usr/bin/unzip -l "$out_aar" | sed -n '1,50p'
}

pack_one "pack.model.gemma270.q8"  "${REPO_ROOT}/models/gemma-3-270m-it-Q8_0.gguf"         "gemma-3-270m-it-Q8_0.gguf"
pack_one "pack.model.qwen05b.q4"   "${REPO_ROOT}/models/qwen2.5-0.5b-instruct-q4_k_m.gguf" "qwen2.5-0.5b-instruct-q4_k_m.gguf"
pack_one "pack.model.gemma1b.iq4"  "${REPO_ROOT}/models/google_gemma-3-1b-it-IQ4_XS.gguf"  "google_gemma-3-1b-it-IQ4_XS.gguf"

echo "== Done =="
/bin/ls -lh "${REPO_ROOT}/out/"*.aar "${REPO_ROOT}/out/sha256sum.txt"
