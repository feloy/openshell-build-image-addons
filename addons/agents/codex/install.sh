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

# CODEX_VERSION must stay in the range accepted by @openai/codex in the ACP adapter.
codex_version="${CODEX_VERSION:-0.159.3}"
codex_acp_version="${CODEX_ACP_VERSION:-v2.1.1}"
codex_acp_sha="${CODEX_ACP_SHA:-68d7d2d5ddfc0ed5746f9f6130892dda685e65dd}"
export HOME=/tmp

mkdir -p /tmp/rootfs/usr/local/bin /tmp/rootfs/usr/local/lib

# Keep the whole standalone package: Codex needs its metadata and bundled tools.
curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh -s -- --release "${codex_version}"
cp -a "$(readlink -f "${HOME}/.codex/packages/standalone/current")" /tmp/rootfs/usr/local/lib/codex
ln -s ../lib/codex/bin/codex /tmp/rootfs/usr/local/bin/codex

ACP_REPOSITORY=https://github.com/agentclientprotocol/codex-acp \
ACP_VERSION="${codex_acp_version}" \
ACP_SHA="${codex_acp_sha}" \
ACP_OUTPUT=codex-acp \
    bash /tmp/build-acp.sh
