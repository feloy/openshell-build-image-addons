#!/usr/bin/env bash
#
# Copyright (C) 2026 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

annotation=ai.openkaiden.openshell-build-image.libc
index="${IMAGE_NAME}:next"

jq -e '
  type == "array" and length > 0 and
  all(.[]; (.libc | type == "string" and test("^[a-z0-9][a-z0-9._-]*$")) and
           (.containerfile | type == "string" and length > 0)) and
  ([.[].libc] | unique | length) == length
' <<< "$VARIANTS_JSON" >/dev/null

buildah manifest create "$index"

variant_lines=$(jq -r '.[] | [.libc, .containerfile] | @tsv' <<< "$VARIANTS_JSON")
while IFS=$'\t' read -r libc containerfile; do
  for arch in amd64 arm64; do
    variant_image="${IMAGE_NAME}:${arch}-${libc}"
    buildah bud --format oci --platform "linux/${arch}" \
      --file "$containerfile" --tag "$variant_image" "$BUILD_CONTEXT"
    buildah manifest add --annotation "${annotation}=${libc}" \
      "$index" "$variant_image"
  done
done <<< "$variant_lines"

# A list can contain repeated platforms, so compare both platform and libc.
expected=$(jq -c '[.[] | .libc as $libc | ["amd64", "arm64"][] |
  {architecture: ., os: "linux", libc: $libc}] | sort_by(.architecture, .libc)' \
  <<< "$VARIANTS_JSON")
buildah manifest inspect "$index" | jq -e \
  --arg annotation "$annotation" --argjson expected "$expected" '
  [.manifests[] |
    {architecture: .platform.architecture, os: .platform.os,
     libc: .annotations[$annotation]}] |
  sort_by(.architecture, .libc) == $expected
' >/dev/null
