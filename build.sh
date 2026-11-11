#!/bin/bash
# Copyright (C) 2026 Hygon Information Technology Co., Ltd.
# SPDX-License-Identifier: MIT

set -eo pipefail
trap 'echo "错误: 第 ${LINENO} 行执行失败" >&2' ERR

# 获取当前工作空间路径
WORK_SPACE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
echo "当前工作空间: ${WORK_SPACE}"
if [ "$(id -u)" -ne 0 ]; then
    echo "错误: 请以 root 身份运行此脚本。" >&2
    exit 1
fi

# 依赖安装
# 备份原镜像源
[ -e /etc/apt/sources.list.bak ] || cp /etc/apt/sources.list /etc/apt/sources.list.bak
# 将原镜像源更换为阿里云镜像源
sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list
while IFS= read -r source; do
    if ! grep -Fqx -- "$source" /etc/apt/sources.list; then
        if [ -s /etc/apt/sources.list ] && [ -n "$(tail -c 1 /etc/apt/sources.list)" ]; then
            printf '\n' >> /etc/apt/sources.list
        fi
        printf '%s\n' "$source" >> /etc/apt/sources.list
    fi
done <<'EOF'
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-security main restricted universe multiverse
EOF

apt update
apt install -y libx11-dev libxrandr-dev
apt install -y pkg-config libgtk-3-dev libv4l-dev libxvidcore-dev libx264-dev libjpeg-dev libpng-dev libtiff-dev gfortran openexr libatlas-base-dev libhdf5-mpich-dev libhdf5-dev libvtk6-dev libopenblas-dev libeigen3-dev libogre-1.12-dev libxaw7-dev libbullet-dev libbullet-extras-dev git-lfs

python -m pip install wheel==0.45.1 scikit-build

apt remove -y libavcodec-dev libavutil-dev
apt remove -y libavfilter7

cd "${WORK_SPACE}/../"
wget -O MacCodecSDK-V1.23.tar.gz https://download.sourcefind.cn:65024/file/5/编解码开发工具/开发工具/MacCodecSDK/dtk26.04/MacCodecSDK-V1.23.tar.gz
tar -zxvf MacCodecSDK-V1.23.tar.gz

cd "${WORK_SPACE}"
git submodule update --init --recursive

source /opt/dtk/env.sh
source /opt/dtk/cuda/cuda-12/env.sh
source "${WORK_SPACE}/../MacCodecSDK/env.sh"
export ENABLE_CONTRIB=1
python setup.py bdist_wheel

# 检查dist目录是否存在
if [ ! -d "${WORK_SPACE}/dist" ]; then
    echo "错误: dist目录不存在!"
    exit 1
fi

# 进入dist目录
cd "${WORK_SPACE}/dist" || {
    echo "错误: 无法进入dist目录!"
    exit 1
}
echo "已进入目录: $(pwd)"

# 安装必要的工具
echo "正在安装patchelf和auditwheel..."
python -m pip install patchelf auditwheel -i http://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com

# 检查pip安装是否成功
if [ $? -ne 0 ]; then
    echo "错误: pip安装失败!"
    exit 1
fi

# 获取平台信息
export PLATFORM=$(ldd --version | awk '{print $NF}' | head -n1 | awk -F "." '{print "manylinux_"$1"_"$2"_x86_64"}')
echo "检测到的平台: ${PLATFORM}"

# 检查wheel文件是否存在
WHL_COUNT=$(ls -1 *.whl 2>/dev/null | wc -l)
if [ $WHL_COUNT -eq 0 ]; then
    echo "错误: 没有找到.whl文件!"
    exit 1
fi
echo "找到 $WHL_COUNT 个.whl文件"

# 执行auditwheel repair
echo "正在执行auditwheel repair..."
auditwheel repair --plat "${PLATFORM}" --strip \
    --exclude libcudnn.so.8 \
    --exclude libcuda.so.1 \
    --exclude libnvcuvid.so.12 \
    --exclude libcublas.so.12 \
    --exclude libcudart.so.12 \
    --exclude libnpp_gpu.so.12 \
    --exclude librpp.so.6 \
    --exclude libcufft.so.11 \
    --exclude libgalaxyhip.so.5 \
    --exclude libhipblas.so.2 \
    --exclude librocblas.so.4 \
    --exclude libhipfft.so.0 \
    --exclude librocsolver.so.0 \
    --exclude librocfft.so.0 \
    --exclude libhipnn.so \
    --exclude librocsparse.so.1 \
    --exclude libMIOpen.so.1 \
    --exclude libMIOpen-recommend.so \
    --exclude libunwind.so.8 \
    --exclude libomp.so \
    --exclude libhipsparse.so.0 \
    --exclude libhipsparse.so.1 \
    --exclude libhiprand.so.1 \
    --exclude libhipsolver.so.0 \
    --exclude librccl.so.1 \
    --exclude librocrand.so.1 \
    --exclude libhipblaslt.so.0 \
    --exclude librocm_smi64.so.2 \
    -w "${WORK_SPACE}/dist/" \
    "${WORK_SPACE}/dist/"*.whl

# 检查auditwheel执行结果
if [ $? -eq 0 ]; then
    echo "auditwheel repair执行成功!"
    echo "修复后的文件保存在: ${WORK_SPACE}/dist/"
else
    echo "错误: auditwheel repair执行失败!"
    exit 1
fi
