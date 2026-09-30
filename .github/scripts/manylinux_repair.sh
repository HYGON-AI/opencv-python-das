#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Hygon Information Technology Co., Ltd.
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Hygon Information Technology Co., Ltd.

# Repair Linux wheels without changing the original files.
# Usage: .github/scripts/manylinux_repair.sh [input_dir=dist] [output_dir=dist-manylinux]

# DTK's env.sh can reference variables that are not initialized, so load it
# before enabling nounset.
if [[ -f /opt/dtk/env.sh ]]; then
    # shellcheck disable=SC1091
    source /opt/dtk/env.sh
fi

set -euo pipefail

input_dir="${1:-dist}"
output_dir="${2:-dist-manylinux}"

if [[ ! -d "${input_dir}" ]]; then
    echo "Input directory does not exist: ${input_dir}" >&2
    exit 1
fi

wheels=("${input_dir}"/*.whl)
if [[ ! -e "${wheels[0]}" ]]; then
    echo "No wheel found in ${input_dir}" >&2
    exit 1
fi

python3 -m pip install --no-cache-dir auditwheel patchelf

glibc_version="$(getconf GNU_LIBC_VERSION | awk '{print $2}')"
platform="manylinux_${glibc_version//./_}_$(uname -m)"

echo "Repairing ${#wheels[@]} wheel(s) for ${platform}"
mkdir -p "${output_dir}"

# These libraries are supplied by the DTK/HCU runtime or by the target system
# and must not be bundled into the OpenCV wheel.
excludes=(
    libcudnn.so.8
    libcuda.so.1
    libnvcuvid.so.12
    libcublas.so.12
    libcudart.so.12
    libnpp_gpu.so.12
    librpp.so.6
    libcufft.so.11
    libgalaxyhip.so.5
    libhipblas.so.2
    librocblas.so.4
    libhipfft.so.0
    librocsolver.so.0
    librocfft.so.0
    libhipnn.so
    librocsparse.so.1
    libMIOpen.so.1
    libMIOpen-recommend.so
    libavcodec.so.61
    libavformat.so.61
    libavutil.so.59
    libswscale.so.8
    libswresample.so.5
    libmacv4l2.so.1
    # GStreamer discovers plugins from the host at runtime. Bundling its core
    # libraries while loading host plugins brings two GStreamer runtimes into
    # one process and causes duplicate GstObject/GstChildProxy registration.
    # Keep the complete GStreamer stack supplied by the target system.
    libgstreamer-1.0.so.0
    libgstapp-1.0.so.0
    libgstaudio-1.0.so.0
    libgstbase-1.0.so.0
    libgstpbutils-1.0.so.0
    libgstriff-1.0.so.0
    libgsttag-1.0.so.0
    libgstvideo-1.0.so.0
    libunwind.so.8
    libomp.so
    libhipsparse.so.0
    libhipsparse.so.1
    libhiprand.so.1
    libhipsolver.so.0
    librccl.so.1
    librocrand.so.1
    libhipblaslt.so.0
    librocm_smi64.so.2
)

exclude_args=()
for library in "${excludes[@]}"; do
    exclude_args+=(--exclude "${library}")
done

auditwheel repair \
    --plat "${platform}" \
    --strip \
    "${exclude_args[@]}" \
    --wheel-dir "${output_dir}" \
    "${wheels[@]}"

repaired_wheels=("${output_dir}"/*.whl)
if [[ ! -e "${repaired_wheels[0]}" ]]; then
    echo "auditwheel did not produce a wheel in ${output_dir}" >&2
    exit 1
fi

printf 'Repaired wheel: %s\n' "${repaired_wheels[@]}"
