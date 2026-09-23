#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Hygon Information Technology Co., Ltd.

set -euo pipefail

: "${DTK_PKG_URL:?DTK_PKG_URL is required}"

dtk_archive="$(mktemp --tmpdir=/opt DTK-package.XXXXXX.tar.gz)"
aicc_installer=""
gst_registry=""

cleanup() {
  rm -f "${dtk_archive}"
  if [[ -n "${aicc_installer}" ]]; then
    rm -f "${aicc_installer}"
  fi
  if [[ -n "${gst_registry}" ]]; then
    rm -f "${gst_registry}"
  fi
}
trap cleanup EXIT

install_dtk() {
  test ! -e /opt/dtk

  wget \
    --quiet \
    --tries=3 \
    --timeout=30 \
    --output-document="${dtk_archive}" \
    "${DTK_PKG_URL}"

  tar -xzf "${dtk_archive}" -C /opt
  rm -f "${dtk_archive}"
  dtk_archive=""

  local extracted_dirs=(/opt/dtk-*)
  test "${#extracted_dirs[@]}" -eq 1
  test -d "${extracted_dirs[0]}"
  mv "${extracted_dirs[0]}" /opt/dtk
  test -f /opt/dtk/env.sh
}

install_aicc() {
  : "${RESOURCE_SERVER_URL:?RESOURCE_SERVER_URL is required}"
  aicc_installer="$(mktemp)"

  wget \
    --quiet \
    --tries=3 \
    --timeout=30 \
    --output-document="${aicc_installer}" \
    "${RESOURCE_SERVER_URL}/ai_cc/Nightly/hcu_llvm_installer.sh"

  bash "${aicc_installer}" --major "${AICC_MAJOR_VERSION:-1.0.0}"
}

install_system_dependencies() {
  local package_manager
  if command -v dnf >/dev/null 2>&1; then
    package_manager=dnf
  elif command -v yum >/dev/null 2>&1; then
    package_manager=yum
  else
    echo "A yum-compatible package manager is required" >&2
    return 1
  fi

  "${package_manager}" install -y \
    dejavu-sans-fonts \
    gstreamer1-plugins-bad-free \
    gstreamer1-plugins-good \
    qt5-qtbase-devel

  # The repository's video fixture is H.264 (avc1). Rocky's base repositories
  # provide the MP4 demuxer and H.264 parser, but intentionally omit a decoder.
  # RPM Fusion's signed EL package supplies avdec_h264 through gstreamer1-libav.
  # Verify this before the two-hour OpenCV build instead of failing at test.
  local rhel_major
  rhel_major="$(rpm -E '%{rhel}')"
  "${package_manager}" install -y epel-release
  "${package_manager}" install -y \
    "https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-${rhel_major}.noarch.rpm"
  "${package_manager}" install -y gstreamer1-libav

  # Package scriptlets can leave a registry that predates the newly installed
  # libav plugin. Scan into a fresh job-local registry.
  gst_registry="$(mktemp)"
  rm -f "${gst_registry}"
  export GST_REGISTRY_1_0="${gst_registry}"

  if gst-inspect-1.0 avdec_h264 >/dev/null 2>&1; then
    echo "GStreamer H.264 decoder: avdec_h264"
  elif gst-inspect-1.0 openh264dec >/dev/null 2>&1; then
    echo "GStreamer H.264 decoder: openh264dec"
  else
    echo "No GStreamer H.264 decoder is available from the configured repositories" >&2
    local libav_plugin
    libav_plugin="$(find /usr/lib64 /usr/lib -path '*/gstreamer-1.0/libgstlibav.so' -print -quit 2>/dev/null || true)"
    if [[ -n "${libav_plugin}" ]]; then
      ldd "${libav_plugin}" >&2 || true
      GST_DEBUG=2 gst-inspect-1.0 "${libav_plugin}" >&2 || true
    fi
    gst-inspect-1.0 | grep -Ei 'h264|openh264|libav' >&2 || true
    return 1
  fi

  local qmake_bin
  qmake_bin="$(command -v qmake-qt5 || command -v qmake || true)"
  if [[ -z "${qmake_bin}" && -x /usr/lib64/qt5/bin/qmake ]]; then
    qmake_bin=/usr/lib64/qt5/bin/qmake
  fi

  if [[ -z "${qmake_bin}" ]]; then
    echo "Qt5 qmake was not found after package installation" >&2
    return 1
  fi

  local qt_plugins_dir
  qt_plugins_dir="$("${qmake_bin}" -query QT_INSTALL_PLUGINS)"
  test -d "${qt_plugins_dir}"

  # setup.py applies patches/patchQtPlugins, which packages plugins from this
  # location. CMake does not traverse a directory symlink during installation.
  install -d /opt/Qt5.15.0/plugins
  cp -a "${qt_plugins_dir}/." /opt/Qt5.15.0/plugins/

  local qt_xcb_plugin=/opt/Qt5.15.0/plugins/platforms/libqxcb.so
  if [[ ! -f "${qt_xcb_plugin}" ]]; then
    echo "Required Qt platform plugin was not found: ${qt_xcb_plugin}" >&2
    find /opt/Qt5.15.0/plugins -maxdepth 2 -type f -print >&2
    return 1
  fi

  echo "Qt5 plugins: ${qt_plugins_dir}"
  echo "Qt5 xcb plugin: ${qt_xcb_plugin}"
}

install_python_dependencies() {
  python3 -m pip install --no-cache-dir \
    numpy==1.26.4 \
    cmake \
    ninja \
    wheel \
    'scikit-build>=0.14.0' \
    setuptools==59.2.0
}

case "${1:-build}" in
  build)
    install_dtk
    install_aicc
    install_system_dependencies
    install_python_dependencies
    ;;
  runtime)
    install_dtk
    install_system_dependencies
    ;;
  *)
    echo "Usage: $0 [build|runtime]" >&2
    exit 2
    ;;
esac
