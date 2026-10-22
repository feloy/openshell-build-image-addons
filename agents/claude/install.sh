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

claude_code_version="${CLAUDE_CODE_VERSION:-2.1.286}"
claude_agent_acp_version="${CLAUDE_AGENT_ACP_VERSION:-v0.85.0}"
claude_agent_acp_sha="${CLAUDE_AGENT_ACP_SHA:-c84845272fe3c55c1f97759f00ee48a1356fccae}"
export HOME=/tmp

mkdir -p /tmp/rootfs

curl -fsSL https://claude.ai/install.sh | bash -s -- "${claude_code_version}"
install -D -m 0755 "$(readlink -f "${HOME}/.local/bin/claude")" /tmp/rootfs/usr/local/bin/claude

ACP_REPOSITORY=https://github.com/agentclientprotocol/claude-agent-acp \
ACP_VERSION="${claude_agent_acp_version}" \
ACP_SHA="${claude_agent_acp_sha}" \
ACP_OUTPUT=claude-agent-acp \
    bash /tmp/build-acp.sh
