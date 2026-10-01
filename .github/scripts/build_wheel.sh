#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Hygon Information Technology Co., Ltd.

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
cmake_define="-D"
export CMAKE_ARGS="${CMAKE_ARGS:-} ${cmake_define}CMAKE_CUDA_COMPILER=${nvcc_path} ${cmake_define}CMAKE_CUDA_COMPILER_FORCED=TRUE ${cmake_define}CUDAToolkit_ROOT=${cuda_root} ${cmake_define}CUDA_TOOLKIT_ROOT_DIR=${cuda_root}"

echo "CUDA compiler: ${nvcc_path}"
echo "CUDA toolkit:  ${cuda_root}"
"${nvcc_path}" --version

export CI_BUILD=1
export ENABLE_CONTRIB=1
export ENABLE_HEADLESS=0
export ENABLE_ROLLING=0

# setup.py normally generates this file when it sees the Git worktree.  Do it
# before temporarily hiding .git below so package versioning remains identical
# to the normal CI build while submodules stay on the revisions selected by the
# workflow.
python3 find_version.py True False False True
test -s cv2/version.py

# The workflow has already authenticated, fetched, and checked out the exact
# OpenCV/OpenCV-contrib revisions that this wheel must build.  setup.py treats
# the presence of the top-level .git directory as a request to run another
# unauthenticated `git submodule update`, which both fails for private
# repositories and would reset the source trees to the stale gitlink commits.
# Hide only the top-level Git metadata while setup.py runs, and always restore
# it so actions/checkout post-job cleanup can still operate normally.
git_metadata_backup=""
restore_git_metadata() {
  if [[ -n "${git_metadata_backup}" && -e "${git_metadata_backup}" ]]; then
    mv -- "${git_metadata_backup}" .git
  fi
}

if [[ -e .git ]]; then
  git_metadata_backup=".git.ci-wheel-build"
  if [[ -e "${git_metadata_backup}" ]]; then
    echo "Refusing to overwrite existing ${git_metadata_backup}" >&2
    exit 1
  fi
  mv -- .git "${git_metadata_backup}"
  trap restore_git_metadata EXIT
fi

python3 setup.py bdist_wheel --py-limited-api=cp37 -v

if [[ -n "${git_metadata_backup}" ]]; then
  restore_git_metadata
  trap - EXIT
fi

compgen -G 'dist/*.whl' >/dev/null
