<div align="center">

OpenCV for HCU

</div>

# Open Source Attribution

This repository is based on [opencv-python](https://github.com/opencv/opencv-python)
and contains Hygon-maintained changes for HCU/ROCm environments. `opencv-python`
is derived from the upstream [opencv-python](https://github.com/opencv/opencv-python/tree/80)
project.

- Modified by Hygon Information Technology Co., Ltd., 2026.
- Direct upstream: [opencv](https://github.com/opencv/opencv-python/tree/80)
- Upstream branch: `4.x`
- Upstream tag: `80`
- Upstream baseline commit: `8ad8ec1bae8aad196b3e9117a4b2b47d58547d47`
- License: MIT License
- Third-party notices: see component license files of `LICENSE-3RD-PARTY.txt` and `THIRD_PARTY_NOTICES.md` as well as preserved third-party notices in the source tree
- Upstream-derived historical reference: [README_ORIGIN.md](README_ORIGIN.md )

# Build and Installation
## Requirements
- Python >= 3.10
- DTK >= 26.04

## Build from Source
You can directly execute `bash build.sh` in the project root directory to build OpenCV

## Testing and Accuracy
Run the public test suite on an HCU device:
```
export OPENCV_TEST_DATA_PATH=opencv-python-das/opencv_extra/testdata
cd opencv-python-das/_skbuild/linux-x86_64-3.10/cmake-build/bin
./opencv_test_cudaarithm --cuda_device 0
./opencv_test_cudaimgproc --cuda_device 0
./opencv_test_cudafilters --cuda_device 0
./opencv_test_cudaobjdetect --cuda_device 0
./opencv_test_cudawarping --cuda_device 0 
./opencv_test_cudalegacy --cuda_device 0
./opencv_test_cudafeatures2d --cuda_device 0
./opencv_test_cudev --cuda_device 0
```

# References
- [OpenCV direct upstream](https://github.com/opencv/opencv-python)
- [Upstream-derived historical reference](README_ORIGIN.md)

# License
MIT License
Additional modifications copyright: Copyright 2026 Hygon Information Technology Co., Ltd.