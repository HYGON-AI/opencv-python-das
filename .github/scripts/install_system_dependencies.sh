#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Hygon Information Technology Co., Ltd.

set -euo pipefail

if command -v dnf >/dev/null 2>&1; then
  package_manager=dnf
elif command -v yum >/dev/null 2>&1; then
  package_manager=yum
else
  echo "A yum-compatible package manager is required" >&2
  exit 1
fi

"${package_manager}" install -y \
  dejavu-sans-fonts \
  qt5-qtbase-devel

qmake_bin="$(command -v qmake-qt5 || command -v qmake || true)"
if [[ -z "${qmake_bin}" && -x /usr/lib64/qt5/bin/qmake ]]; then
  qmake_bin=/usr/lib64/qt5/bin/qmake
fi

if [[ -z "${qmake_bin}" ]]; then
  echo "Qt5 qmake was not found after package installation" >&2
  exit 1
fi

qt_plugins_dir="$("${qmake_bin}" -query QT_INSTALL_PLUGINS)"
test -d "${qt_plugins_dir}"

# setup.py applies patches/patchQtPlugins, which packages plugins from this
# location. CMake's install(DIRECTORY ...) does not traverse a directory
# symlink, so copy the packaged Qt plugins instead of linking the directory.
install -d /opt/Qt5.15.0/plugins
cp -a "${qt_plugins_dir}/." /opt/Qt5.15.0/plugins/

qt_xcb_plugin=/opt/Qt5.15.0/plugins/platforms/libqxcb.so
if [[ ! -f "${qt_xcb_plugin}" ]]; then
  echo "Required Qt platform plugin was not found: ${qt_xcb_plugin}" >&2
  find /opt/Qt5.15.0/plugins -maxdepth 2 -type f -print >&2
  exit 1
fi

echo "Qt5 plugins: ${qt_plugins_dir}"
echo "Qt5 xcb plugin: ${qt_xcb_plugin}"
