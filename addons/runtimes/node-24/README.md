<!--

Copyright (C) 2026 Red Hat, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

SPDX-License-Identifier: Apache-2.0
-->

# Node.js 24 addon

[Containerfile.glibc](Containerfile.glibc) and
[Containerfile.musl](Containerfile.musl) package Node.js 24.22.3 from digest-pinned
official Node images. The payload includes `node`, `nodejs`, npm, npx, Corepack,
headers for native modules, documentation, and the Node license with its bundled
dependency notices. The upstream image's Yarn installation and container
entrypoint are omitted.

The workflows publish the addon as
`ghcr.io/openkaiden/openshell-build-image-addons-node-24:next`, with `linux/amd64` and
`linux/arm64` images for both `glibc` and `musl`. Select the descriptor matching
your base image's architecture and libc using the
[index inspection example](../../../README.md#inspect-the-published-index),
then copy its files and carry over its environment:

```Dockerfile
COPY --from=ghcr.io/openkaiden/openshell-build-image-addons-node-24@sha256:<selected-digest> / /
ENV PATH=/usr/local/bin:${PATH}
```

The addon includes `libstdc++` and `libgcc_s` in `/usr/local/lib/node-24`, plus
`libatomic` for musl. Node's ELF RUNPATH prefers the base image's standard library
directories, then falls back to this private directory. This also lets native
modules use a newer C++ runtime supplied by the base image. The base image must
supply a matching libc and `/bin/sh` for npm scripts. The glibc variant's
Debian 12 fallback libraries require glibc 2.36 or newer. The musl variant uses
Alpine 3.24 libraries. Corepack can download
additional package managers when requested; they are not preinstalled.

Native module builds also need Python, make, and a C/C++ compiler in the base
image. Set `npm_package_config_node_gyp_nodedir=/usr/local` to use the bundled
Node headers with npm's node-gyp.

Node 24.22.3 passed consumer-image checks on:

| Base image | Variant | Architectures |
| --- | --- | --- |
| UBI 10 (glibc 2.39) | `glibc` | `amd64`, `arm64` |
| Alpine 3.24.2 (musl 1.2.6) | `musl` | `amd64`, `arm64` |

ARM64 ran natively and amd64 under emulation. Checks covered the package managers,
crypto and worker threads, local npm installation, npm scripts, and npx commands
as root and UID 65532. A C++ native module compiled using the bundled headers and
loaded successfully on all four variants. UBI's package manager also worked after
copying the addon. Both glibc architectures passed a separate check with the base
image's C++ runtime libraries removed, confirming use of the private fallbacks.

To update Node 24, update the version comments and source image digests in both
Containerfiles together. Also update the license URL and its SHA-256 checksum in
both files. The source images already contain matching package-manager versions;
there are no separate version build arguments.

See [image builds](../../../.github/IMAGE-BUILDS.md) for the build and publishing
workflows.
