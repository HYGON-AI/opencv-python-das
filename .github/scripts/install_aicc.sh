#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Hygon Information Technology Co., Ltd.

set -euo pipefail

: "${RESOURCE_SERVER_URL:?RESOURCE_SERVER_URL is required}"

installer="$(mktemp)"
trap 'rm -f "${installer}"' EXIT

wget \
  --quiet \
  --tries=3 \
  --timeout=30 \
  --output-document="${installer}" \
  "${RESOURCE_SERVER_URL}/ai_cc/Nightly/hcu_llvm_installer.sh"

bash "${installer}" --major "${AICC_MAJOR_VERSION:-1.0.0}"
