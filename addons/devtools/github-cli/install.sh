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

gh_version="${GH_VERSION:-2.103.3}"
case "$(uname -m)" in
    x86_64) arch=amd64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

# Upstream Linux binaries use CGO_ENABLED=0 and support both glibc and musl.
release_dir="gh_${gh_version}_linux_${arch}"
archive="${release_dir}.tar.gz"
release_url="https://github.com/cli/cli/releases/download/v${gh_version}"
curl -fsSL "${release_url}/${archive}" -o "${tmp_dir}/${archive}"
curl -fsSL "${release_url}/gh_${gh_version}_checksums.txt" -o "${tmp_dir}/checksums.txt"
(
    cd "$tmp_dir"
    grep -F "  ${archive}" checksums.txt | sha256sum -c -
)

tar -xzf "${tmp_dir}/${archive}" -C "$tmp_dir" "${release_dir}/bin/gh" "${release_dir}/LICENSE"
install -D -m 0755 "${tmp_dir}/${release_dir}/bin/gh" /tmp/rootfs/usr/local/bin/gh
install -D -m 0644 "${tmp_dir}/${release_dir}/LICENSE" /tmp/rootfs/usr/local/share/licenses/github-cli/LICENSE
