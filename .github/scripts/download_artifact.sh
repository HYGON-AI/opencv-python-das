#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Hygon Information Technology Co., Ltd.

set -euo pipefail

: "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"

run_id="${1:?Usage: $0 RUN_ID [ARTIFACT_PATTERN] [OUTPUT_DIR]}"
artifact_pattern="${2:-opencv-python-das-*}"
output_dir="${3:-wheelhouse}"
api_url="${GITHUB_API_URL:-https://api.github.com}"

metadata_file="$(mktemp)"
archive_file="$(mktemp --suffix=.zip)"
cleanup() {
  rm -f "${metadata_file}" "${archive_file}"
}
trap cleanup EXIT

curl \
  --fail \
  --silent \
  --show-error \
  --retry 5 \
  --retry-delay 5 \
  --connect-timeout 30 \
  --max-time 120 \
  --header "Authorization: Bearer ${GITHUB_TOKEN}" \
  --header "Accept: application/vnd.github+json" \
  --output "${metadata_file}" \
  "${api_url}/repos/${GITHUB_REPOSITORY}/actions/runs/${run_id}/artifacts?per_page=100"

artifact_id="$(python3 - "${metadata_file}" "${artifact_pattern}" <<'PY'
import fnmatch
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    artifacts = json.load(stream).get("artifacts", [])

matches = [
    artifact
    for artifact in artifacts
    if not artifact.get("expired")
    and fnmatch.fnmatchcase(artifact["name"], sys.argv[2])
]
if len(matches) != 1:
    names = ", ".join(artifact["name"] for artifact in artifacts) or "none"
    raise SystemExit(
        f"Expected one artifact matching {sys.argv[2]!r}; "
        f"found {len(matches)}. Available artifacts: {names}"
    )

print(matches[0]["id"])
PY
)"

echo "Downloading artifact ${artifact_id} from run ${run_id}"
curl \
  --fail \
  --location \
  --show-error \
  --retry 5 \
  --retry-delay 5 \
  --connect-timeout 30 \
  --max-time 3600 \
  --continue-at - \
  --header "Authorization: Bearer ${GITHUB_TOKEN}" \
  --header "Accept: application/vnd.github+json" \
  --output "${archive_file}" \
  "${api_url}/repos/${GITHUB_REPOSITORY}/actions/artifacts/${artifact_id}/zip"

python3 - "${archive_file}" "${output_dir}" <<'PY'
from pathlib import Path
import sys
import zipfile

archive_path = Path(sys.argv[1])
output_dir = Path(sys.argv[2]).resolve()
output_dir.mkdir(parents=True, exist_ok=True)

with zipfile.ZipFile(archive_path) as archive:
    for member in archive.infolist():
        destination = (output_dir / member.filename).resolve()
        if destination != output_dir and output_dir not in destination.parents:
            raise RuntimeError(f"Unsafe artifact path: {member.filename}")
    archive.extractall(output_dir)

print(f"Extracted artifact to {output_dir}")
PY
