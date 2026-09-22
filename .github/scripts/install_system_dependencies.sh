#!/usr/bin/env bash

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
# location. The upstream manylinux image provides a source-built Qt here;
# expose Rocky Linux's packaged Qt plugins at the same stable path.
mkdir -p /opt/Qt5.15.0
if [[ ! -e /opt/Qt5.15.0/plugins ]]; then
  ln -s "${qt_plugins_dir}" /opt/Qt5.15.0/plugins
fi

echo "Qt5 plugins: ${qt_plugins_dir}"
