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

# Update the default version and pinned source checksum together.
default_git_version=2.56.1
git_version="${GIT_VERSION:-${default_git_version}}"
checksum="${GIT_SHA256:-}"
if [[ -z "$checksum" && "$git_version" == "$default_git_version" ]]; then
    checksum=f0b0bf89264b9bd2e1c640363e7529643989da76281600473c50745cd34a607f
fi
if [[ ! "$checksum" =~ ^[[:xdigit:]]{64}$ ]]; then
    echo "Set GIT_SHA256 to the source archive's SHA-256 checksum when overriding GIT_VERSION" >&2
    exit 1
fi

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
archive="git-${git_version}.tar.xz"
curl -fsSL "https://www.kernel.org/pub/software/scm/git/${archive}" -o "${tmp_dir}/${archive}"
(
    cd "$tmp_dir"
    printf '%s  %s\n' "$checksum" "$archive" | sha256sum -c -
)
mkdir "${tmp_dir}/source"
tar -xJf "${tmp_dir}/${archive}" -C "${tmp_dir}/source" --strip-components=1

# Build a private static libcurl without libidn2/libpsl. Alpine's libidn2
# includes a gnulib error() symbol that conflicts with Git when linked statically.
# Keep TLS, HTTP/2, proxies and gzip, without the optional IDN/cookie-domain code.
curl_version=8.23.0
curl_checksum=8dadd7d2536a314f982ad05a651b713f426bf7d02cc2c76cffb9796f2218e6c5
curl_archive="curl-${curl_version}.tar.xz"
curl -fsSL "https://curl.se/download/${curl_archive}" -o "${tmp_dir}/${curl_archive}"
(
    cd "$tmp_dir"
    printf '%s  %s\n' "$curl_checksum" "$curl_archive" | sha256sum -c -
)
mkdir "${tmp_dir}/curl-source"
tar -xJf "${tmp_dir}/${curl_archive}" -C "${tmp_dir}/curl-source" --strip-components=1
(
    cd "${tmp_dir}/curl-source"
    ./configure --prefix="${tmp_dir}/curl" --disable-shared --enable-static \
        --disable-docs --disable-manual --disable-ldap --disable-ldaps \
        --with-openssl --with-zlib --with-nghttp2 \
        --without-libidn2 --without-libpsl --without-brotli --without-zstd
    make -j"$(nproc)"
    make install
)

cd "${tmp_dir}/source"

# libcurl's private dependencies must also be linked statically for HTTPS.
# Omit optional interpreters and translations from this portable CLI addon.
make_options=(
    prefix=/usr/local
    LDFLAGS=-static
    "CURLDIR=${tmp_dir}/curl"
    "CURL_LDFLAGS=$(PKG_CONFIG_PATH="${tmp_dir}/curl/lib/pkgconfig" pkg-config --static --libs libcurl)"
    INSTALL_SYMLINKS=YesPlease
    NO_GETTEXT=YesPlease
    NO_ICONV=YesPlease
    NO_PERL=YesPlease
    NO_PYTHON=YesPlease
    # musl lacks REG_STARTEND; use Git's bundled regex implementation.
    NO_REGEX=NeedsStartEnd
    # Keep the C implementations of subsystems that optionally use Rust.
    NO_RUST=YesPlease
    NO_TCLTK=YesPlease
)
make -j"$(nproc)" "${make_options[@]}"
make "${make_options[@]}" DESTDIR=/tmp/rootfs install

# Refuse to package binaries that need a runtime dynamic loader or libraries.
while IFS= read -r -d '' binary; do
    if ! readelf -h "$binary" >/dev/null 2>&1; then
        continue
    fi
    if readelf -l "$binary" | grep INTERP >/dev/null || readelf -d "$binary" | grep NEEDED >/dev/null; then
        echo "Expected a statically linked binary: ${binary}" >&2
        exit 1
    fi
    strip "$binary"
done < <(find /tmp/rootfs/usr/local/bin /tmp/rootfs/usr/local/libexec -type f -print0)

install -D -m 0644 COPYING /tmp/rootfs/usr/local/share/licenses/git/COPYING
install -D -m 0644 "${tmp_dir}/curl-source/COPYING" /tmp/rootfs/usr/local/share/licenses/curl/COPYING
# Use a private bundle to support bases with different system certificate paths.
install -D -m 0644 /etc/ssl/certs/ca-certificates.crt /tmp/rootfs/usr/local/share/git/ca-certificates.crt
