#!/bin/sh
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

set -eu

mkdir -p /tmp/rootfs/usr/local/bin /tmp/rootfs/usr/local/lib/node-24 \
    /tmp/rootfs/usr/local/include /tmp/rootfs/usr/local/share

# Keep package-manager symlinks and their complete packages together.
cp -RP /usr/local/bin/node /usr/local/bin/npm /usr/local/bin/npx \
    /usr/local/bin/corepack /tmp/rootfs/usr/local/bin/
ln -s node /tmp/rootfs/usr/local/bin/nodejs
cp -RP /usr/local/lib/node_modules /tmp/rootfs/usr/local/lib/
# Local headers let node-gyp build native modules without fetching them again.
cp -RP /usr/local/include/node /tmp/rootfs/usr/local/include/
cp -RP /usr/local/share/doc /usr/local/share/man /tmp/rootfs/usr/local/share/
