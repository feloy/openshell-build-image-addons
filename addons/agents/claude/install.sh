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

# Configure the Claude Code release below.
readonly DEFAULT_CLAUDE_CODE_VERSION="2.1.286"
readonly CLAUDE_INSTALL_URL="https://claude.ai/install.sh"

# Nothing else to configure below this line.
claude_code_version="${CLAUDE_CODE_VERSION:-${DEFAULT_CLAUDE_CODE_VERSION}}"
export HOME=/tmp

mkdir -p /tmp/rootfs

curl -fsSL "${CLAUDE_INSTALL_URL}" | bash -s -- "${claude_code_version}"
install -D -m 0755 "$(readlink -f "${HOME}/.local/bin/claude")" /tmp/rootfs/usr/local/bin/claude
