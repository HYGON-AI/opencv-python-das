#!/usr/bin/env bash

set -euo pipefail

: "${SUBMODULES_READ_TOKEN:?SUBMODULES_READ_TOKEN is required}"

max_attempts="${SUBMODULE_RETRY_ATTEMPTS:-3}"
auth_header="$(
  printf 'x-access-token:%s' "${SUBMODULES_READ_TOKEN}" |
    base64 |
    tr -d '\r\n'
)"

git submodule sync --recursive

for ((attempt = 1; attempt <= max_attempts; attempt++)); do
  echo "Initializing submodules (attempt ${attempt}/${max_attempts})"

  if git \
    -c http.version=HTTP/1.1 \
    -c http.maxRequests=1 \
    -c "http.https://github.com/.extraheader=AUTHORIZATION: basic ${auth_header}" \
    submodule update \
    --init \
    --force \
    --recursive \
    --depth 1 \
    --jobs 1; then
    unset auth_header
    echo "Submodules initialized successfully"
    exit 0
  fi

  if ((attempt == max_attempts)); then
    unset auth_header
    echo "Failed to initialize submodules after ${max_attempts} attempts" >&2
    exit 1
  fi

  retry_delay=$((attempt * 15))
  echo "Submodule checkout failed; retrying in ${retry_delay}s" >&2
  sleep "${retry_delay}"
done
