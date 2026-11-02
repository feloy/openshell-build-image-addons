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

opencode_version="${OPENCODE_VERSION:-2.2.5}"
export HOME=/tmp

mkdir -p /tmp/rootfs

curl -fsSL https://opencode.ai/v2/install | bash -s -- --version "${opencode_version}" --no-modify-path
install -D -m 0755 "${HOME}/.opencode/bin/opencode" /tmp/rootfs/usr/local/bin/opencode
