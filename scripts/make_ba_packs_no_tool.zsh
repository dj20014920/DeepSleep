#!/bin/zsh
set -euo pipefail

mkdir -p models out tmp

# 1) 모델 다운로드(이미 있으면 스킵)
if [[ ! -f models/gemma-3-270m-it-Q8_0.gguf ]]; then
  hf download unsloth/gemma-3-270m-it-GGUF --include "gemma-3-270m-it-Q8_0.gguf" --local-dir "models"
fi
if [[ ! -f models/qwen2.5-0.5b-instruct-q4_k_m.gguf ]]; then
  hf download Qwen/Qwen2.5-0.5B-Instruct-GGUF --include "qwen2.5-0.5b-instruct-q4_k_m.gguf" --local-dir "models"
fi
if [[ ! -f models/google_gemma-3-1b-it-IQ4_XS.gguf ]]; then
  hf download bartowski/google_gemma-3-1b-it-GGUF --include "google_gemma-3-1b-it-IQ4_XS.gguf" --local-dir "models"
fi

# 2) sha256 기록
shasum -a 256 models/*.gguf | tee out/sha256sum.txt

# 3) 수동 패킹 함수 (zip -0 으로 무압축, 경로/파일명 고정)
pack_one () {
  local pack_id="$1"
  local src_path="$2"
  local dest_name="$3"
  local manifest="tmp/${pack_id}/manifest.json"
  local workdir="tmp/${pack_id}"
  local aar="out/${pack_id}.aar"

  rm -rf "$workdir" "$aar"
  mkdir -p "$workdir"

  # manifest.json 생성 (compression=none)
  cat > "$manifest" <<JSON
{
  "id": "${pack_id}",
  "resources": [
    { "source": "${dest_name}", "destination": "${dest_name}", "compression": "none" }
  ]
}
JSON

  # 리소스 파일을 패키지 루트에 배치
  cp -f "$src_path" "${workdir}/${dest_name}"

  # zip 무압축(-0), 확장속성 제거(-X), 파일 순서 고정
  (cd "$workdir" && /usr/bin/zip -0 -X "../${pack_id}.aar" "manifest.json" "${dest_name}")

  /usr/bin/unzip -l "$aar" | sed -n '1,50p'
}

# 4) 세 팩 생성
pack_one "pack.model.gemma270.q8"  "models/gemma-3-270m-it-Q8_0.gguf"             "gemma-3-270m-it-Q8_0.gguf"
pack_one "pack.model.qwen05b.q4"   "models/qwen2.5-0.5b-instruct-q4_k_m.gguf"     "qwen2.5-0.5b-instruct-q4_k_m.gguf"
pack_one "pack.model.gemma1b.iq4"  "models/google_gemma-3-1b-it-IQ4_XS.gguf"      "google_gemma-3-1b-it-IQ4_XS.gguf"

echo "== Done =="
/bin/ls -lh out/*.aar out/sha256sum.txt
