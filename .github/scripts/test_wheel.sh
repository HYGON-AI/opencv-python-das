#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Hygon Information Technology Co., Ltd.

set -euo pipefail

# DTK environment scripts append to variables that may not exist in a clean
# runtime container, so disable nounset only while sourcing vendor scripts.
set +u
# shellcheck disable=SC1091
source /opt/dtk/env.sh
for cuda_env in /opt/dtk/cuda/env.sh /opt/dtk/cuda/cuda/env.sh; do
  if [[ -f "${cuda_env}" ]]; then
    # shellcheck disable=SC1090
    source "${cuda_env}"
  fi
done
set -u

wheel_dir="${1:-wheelhouse}"
wheels=("${wheel_dir}"/*.whl)
if [[ "${#wheels[@]}" -ne 1 || ! -f "${wheels[0]}" ]]; then
  echo "Expected exactly one wheel in ${wheel_dir}" >&2
  exit 1
fi

(
  cd "${wheel_dir}"
  sha256sum -c SHA256SUMS
)

venv_dir="$(mktemp -d)"
cleanup() {
  rm -rf "${venv_dir}"
}
trap cleanup EXIT

python3 -m venv "${venv_dir}"
# shellcheck disable=SC1090
source "${venv_dir}/bin/activate"
python -m pip install --no-cache-dir numpy==1.26.4 "${wheels[0]}"

(
  cd tests
  # A broken multimedia dependency can block VideoCapture during plugin
  # discovery. Fail with a useful exit status instead of occupying a runner
  # until the job-level timeout expires.
  timeout --signal=TERM --kill-after=15s 120s python -m unittest -v test.py
  python get_build_info.py
)

python - <<'PY'
import re

import cv2
import numpy as np

build_info = cv2.getBuildInformation()
if not re.search(r"NVIDIA CUDA:\s+YES", build_info):
    raise RuntimeError("The installed wheel was not built with CUDA support")

device_count = cv2.cuda.getCudaEnabledDeviceCount()
if device_count < 1:
    raise RuntimeError("No CUDA/HCU device is visible to OpenCV")

source = np.arange(64, dtype=np.uint8).reshape(8, 8)
device = cv2.cuda_GpuMat()
device.upload(source)
np.testing.assert_array_equal(device.download(), source)

print(f"OpenCV {cv2.__version__}: CUDA/HCU smoke test passed on {device_count} device(s)")
PY
