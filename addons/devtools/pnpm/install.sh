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

# Configure the pnpm release below. Update the version and all four archive checksums together.
readonly DEFAULT_PNPM_VERSION="12.21.0"
readonly PNPM_LINUX_X64_SHA256="84c4773bcf4a217f4083cd7b2a91e4cee6103cf42426c1282ef37d308f55a410"
readonly PNPM_LINUX_ARM64_SHA256="6c5913a48c93b3a556b71c3bd9bf12c6bf9fbfbbbd2dcbd1d52a85c539751b9e"
readonly PNPM_LINUX_X64_MUSL_SHA256="6dbcd9ea8ed37b5acbe279159ad0ed3a4ac614f5d7ae62d5ba51d32a85a589d7"
readonly PNPM_LINUX_ARM64_MUSL_SHA256="4faedaaa333b44d940ce5e38c223e829124affdbe5a6d3f694a69dd979a5a8d8"
readonly DEFAULT_PNPM_LICENSE_SHA256="80a07635e0db9aa83758bf4c8d779a673d60c7e09ca315a91375af1a97abe0b0"
readonly PNPM_RELEASES_URL="https://github.com/pnpm/pnpm/releases/download"
readonly PNPM_SOURCE_URL="https://raw.githubusercontent.com/pnpm/pnpm"

# Nothing else to configure below this line.
export HOME=/tmp
pnpm_version="${PNPM_VERSION:-${DEFAULT_PNPM_VERSION}}"
# The builder runs on the requested target platform, using emulation if needed.
case "$(uname -m)" in
    x86_64) arch=x64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac
case "${1:-}" in
    glibc) target="linux-${arch}" ;;
    musl) target="linux-${arch}-musl" ;;
    *) echo "Usage: $0 <glibc|musl>" >&2; exit 1 ;;
esac

checksum="${PNPM_SHA256:-}"
if [[ -z "$checksum" && "$pnpm_version" == "$DEFAULT_PNPM_VERSION" ]]; then
    case "$target" in
        linux-x64) checksum="$PNPM_LINUX_X64_SHA256" ;;
        linux-arm64) checksum="$PNPM_LINUX_ARM64_SHA256" ;;
        linux-x64-musl) checksum="$PNPM_LINUX_X64_MUSL_SHA256" ;;
        linux-arm64-musl) checksum="$PNPM_LINUX_ARM64_MUSL_SHA256" ;;
    esac
fi
if [[ ! "$checksum" =~ ^[[:xdigit:]]{64}$ ]]; then
    echo "Set PNPM_SHA256 to the target archive's SHA-256 checksum when overriding PNPM_VERSION" >&2
    exit 1
fi

# A version override may reuse this checksum if the license text is unchanged.
license_checksum="${PNPM_LICENSE_SHA256:-${DEFAULT_PNPM_LICENSE_SHA256}}"
if [[ ! "$license_checksum" =~ ^[[:xdigit:]]{64}$ ]]; then
    echo "PNPM_LICENSE_SHA256 must be a SHA-256 checksum" >&2
    exit 1
fi

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
archive="pnpm-${target}.tar.gz"
curl -fsSL "${PNPM_RELEASES_URL}/v${pnpm_version}/${archive}" -o "${tmp_dir}/${archive}"
curl -fsSL "${PNPM_SOURCE_URL}/v${pnpm_version}/pnpm/LICENSE" -o "${tmp_dir}/LICENSE"
(
    cd "$tmp_dir"
    printf '%s  %s\n' "$checksum" "$archive" "$license_checksum" LICENSE | sha256sum -c -
)

# pnpm resolves bundled node-gyp relative to its real executable location.
tar -xzf "${tmp_dir}/${archive}" -C "$tmp_dir" pnpm dist
install -D -m 0755 "${tmp_dir}/pnpm" /tmp/rootfs/usr/local/lib/pnpm/pnpm
cp -RP "${tmp_dir}/dist" /tmp/rootfs/usr/local/lib/pnpm/
mkdir -p /tmp/rootfs/usr/local/bin
ln -s ../lib/pnpm/pnpm /tmp/rootfs/usr/local/bin/pnpm
printf '#!/bin/sh\nexec /usr/local/bin/pnpm dlx "$@"\n' > /tmp/rootfs/usr/local/bin/pnpx
chmod 0755 /tmp/rootfs/usr/local/bin/pnpx
install -D -m 0644 "${tmp_dir}/LICENSE" /tmp/rootfs/usr/local/share/licenses/pnpm/LICENSE
