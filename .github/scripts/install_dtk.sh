#!/usr/bin/env bash

set -euo pipefail

: "${DTK_PKG_URL:?DTK_PKG_URL is required}"

archive_path="$(mktemp --tmpdir=/opt DTK-package.XXXXXX.tar.gz)"
trap 'rm -f "${archive_path}"' EXIT

test ! -e /opt/dtk

wget \
  --quiet \
  --tries=3 \
  --timeout=30 \
  --output-document="${archive_path}" \
  "${DTK_PKG_URL}"

cd /opt
tar -xzf "${archive_path}"
rm -f "${archive_path}"

extracted_dirs=(dtk-*)
test "${#extracted_dirs[@]}" -eq 1
test -d "${extracted_dirs[0]}"
mv "${extracted_dirs[0]}" dtk

test -f /opt/dtk/env.sh
