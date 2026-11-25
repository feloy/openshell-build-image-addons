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

# Configure the ACP repository and adapter releases below. Update each tag and commit SHA together.
readonly ACP_REPOSITORY_BASE_URL="https://github.com/agentclientprotocol"

readonly DEFAULT_CLAUDE_ACP_VERSION="v0.85.0"
readonly DEFAULT_CLAUDE_ACP_SHA="c84845272fe3c55c1f97759f00ee48a1356fccae"

readonly DEFAULT_CODEX_ACP_VERSION="v2.1.1"
readonly DEFAULT_CODEX_ACP_SHA="68d7d2d5ddfc0ed5746f9f6130892dda685e65dd"

# Nothing else to configure below this line.
: "${ACP_OUTPUT:?ACP_OUTPUT is required}"

case "${ACP_OUTPUT}" in
    claude-agent-acp)
        version="${ACP_VERSION:-${DEFAULT_CLAUDE_ACP_VERSION}}"
        sha="${ACP_SHA:-${DEFAULT_CLAUDE_ACP_SHA}}"
        ;;
    codex-acp)
        version="${ACP_VERSION:-${DEFAULT_CODEX_ACP_VERSION}}"
        sha="${ACP_SHA:-${DEFAULT_CODEX_ACP_SHA}}"
        ;;
    *)
        : "${ACP_REPOSITORY:?ACP_REPOSITORY is required for an unlisted adapter}"
        version="${ACP_VERSION:?ACP_VERSION is required for an unlisted adapter}"
        sha="${ACP_SHA:?ACP_SHA is required for an unlisted adapter}"
        ;;
esac

repository="${ACP_REPOSITORY:-${ACP_REPOSITORY_BASE_URL}/${ACP_OUTPUT}}"
checkout="/tmp/${ACP_OUTPUT}"

git clone --depth 1 --branch "${version}" "${repository}" "${checkout}"
test "$(git -C "${checkout}" rev-parse HEAD)" = "${sha}"
cd "${checkout}"
bun install
mkdir -p /tmp/rootfs/usr/local/bin
bun build --compile src/index.ts --outfile "/tmp/rootfs/usr/local/bin/${ACP_OUTPUT}"
