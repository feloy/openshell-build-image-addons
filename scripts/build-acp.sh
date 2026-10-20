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

: "${ACP_REPOSITORY:?ACP_REPOSITORY is required}"
: "${ACP_VERSION:?ACP_VERSION is required}"
: "${ACP_SHA:?ACP_SHA is required}"
: "${ACP_OUTPUT:?ACP_OUTPUT is required}"

checkout="/tmp/${ACP_OUTPUT}"

git clone --depth 1 --branch "${ACP_VERSION}" "${ACP_REPOSITORY}" "${checkout}"
test "$(git -C "${checkout}" rev-parse HEAD)" = "${ACP_SHA}"
cd "${checkout}"
bun install
mkdir -p /tmp/rootfs/usr/local/bin
bun build --compile src/index.ts --outfile "/tmp/rootfs/usr/local/bin/${ACP_OUTPUT}"
