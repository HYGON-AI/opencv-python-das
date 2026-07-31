#!/bin/bash
# Copyright (c) 2026 Hygon Information Technology Co., Ltd.

# 获取当前工作空间路径
WORK_SPACE=$(pwd)
echo "当前工作空间: ${WORK_SPACE}"

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
pip install patchelf auditwheel -i http://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com

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
    --exclude libavcodec.so.61 \
    --exclude libavformat.so.61 \
    --exclude libavutil.so.59 \
    --exclude libswscale.so.8 \
    --exclude libswresample.so.5 \
    --exclude libmacv4l2.so.1 \
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
