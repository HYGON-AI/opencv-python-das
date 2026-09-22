#!/usr/bin/env bash

set -eo pipefail

source /opt/dtk/env.sh

# DTK 26.04 ships its CUDA-compatible compiler in a nested CUDA toolkit.
# The top-level environment does not always add that compiler to PATH.
for cuda_env in /opt/dtk/cuda/env.sh /opt/dtk/cuda/cuda/env.sh; do
  if [[ -f "${cuda_env}" ]]; then
    source "${cuda_env}"
  fi
done

nvcc_path="$(command -v nvcc || true)"
if [[ -z "${nvcc_path}" ]]; then
  nvcc_path="$(find /opt/dtk -type f -path '*/bin/nvcc' -perm /111 -print -quit)"
fi

if [[ -z "${nvcc_path}" ]]; then
  echo "DTK CUDA compiler (nvcc) was not found under /opt/dtk" >&2
  find /opt/dtk -maxdepth 4 -type f \( -name 'nvcc' -o -name 'clang++' \) -print >&2
  exit 1
fi

cuda_root="$(cd "$(dirname "${nvcc_path}")/.." && pwd)"
export PATH="$(dirname "${nvcc_path}"):${PATH}"
export CUDA_PATH="${cuda_root}"
export CUDA_BIN_PATH="${cuda_root}"
export CUDACXX="${nvcc_path}"
export CUDAToolkit_ROOT="${cuda_root}"
export CMAKE_ARGS="${CMAKE_ARGS:-} -DCMAKE_CUDA_COMPILER=${nvcc_path} -DCMAKE_CUDA_COMPILER_FORCED=TRUE -DCUDAToolkit_ROOT=${cuda_root} -DCUDA_TOOLKIT_ROOT_DIR=${cuda_root}"

echo "CUDA compiler: ${nvcc_path}"
echo "CUDA toolkit:  ${cuda_root}"
"${nvcc_path}" --version

export CI_BUILD=1
export ENABLE_CONTRIB=1
export ENABLE_HEADLESS=0
export ENABLE_ROLLING=0

python3 setup.py bdist_wheel --py-limited-api=cp37 -v
compgen -G 'dist/*.whl' >/dev/null
