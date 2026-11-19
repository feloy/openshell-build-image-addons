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

# pnpm addon

[Containerfile.glibc](Containerfile.glibc) and
[Containerfile.musl](Containerfile.musl) package pnpm 12.21.0 from upstream native
release archives, verified with pinned SHA-256 checksums. The payload includes
`pnpm`, a `pnpx` launcher for `pnpm dlx`, the bundled node-gyp support files and
their supplied licenses, and pnpm's license. The binary and its support files
stay together in `/usr/local/lib/pnpm`, with commands in `/usr/local/bin`.

The workflows publish the addon as
`ghcr.io/openkaiden/openshell-build-image-addons-pnpm:next`, with `linux/amd64` and
`linux/arm64` images for both `glibc` and `musl`. Select the descriptor matching
your base image's architecture and libc using the
[index inspection example](../../../README.md#inspect-the-published-index),
then copy its files and carry over its environment:

```Dockerfile
COPY --from=ghcr.io/openkaiden/openshell-build-image-addons-pnpm@sha256:<selected-digest> / /
ENV PATH=/usr/local/bin:${PATH}
```

pnpm 12 runs without Node.js and can install packages with scripts disabled.
Provide Node.js for JavaScript project scripts, JavaScript commands launched with
`pnpm exec` or `pnpx`, and node-gyp. Combine this addon with the
[Node.js 24 addon](../../runtimes/node-24/README.md) when needed. For example,
select both addons' descriptors for the same architecture and libc:

```Dockerfile
FROM registry.access.redhat.com/ubi10/ubi:latest
COPY --from=ghcr.io/openkaiden/openshell-build-image-addons-node-24@sha256:<node-digest> / /
COPY --from=ghcr.io/openkaiden/openshell-build-image-addons-pnpm@sha256:<pnpm-digest> / /
ENV PATH=/usr/local/bin:${PATH}
```

The glibc variant needs the base image's glibc loader and `libgcc_s.so.1`. The musl
binary is statically linked. Provide CA certificates for HTTPS access, `/bin/sh`
and standard shell utilities for project scripts and `pnpx`, and writable home,
cache, and project directories for the runtime user. Native module builds also
need Python, make, and a C/C++ compiler. With the Node.js 24 addon, set
`npm_package_config_node_gyp_nodedir=/usr/local` to use its bundled Node headers.

pnpm 12.21.0 passed consumer-image checks on:

| Base image | Variant | Architectures |
| --- | --- | --- |
| UBI 10 | `glibc` | `amd64`, `arm64` |
| Alpine 3.24.2 | `musl` | `amd64`, `arm64` |

ARM64 ran natively and amd64 under emulation. Checks covered standalone
installation without Node.js, local and HTTPS dependencies, frozen offline
installs, project scripts, `pnpm exec`, and `pnpx`, as root and UID 65532. The
bundled node-gyp compiled a native module that loaded successfully with the
Node.js 24 addon on all four variants.

To update pnpm, change the default version and all four archive checksums in
[install.sh](install.sh) together. Update the license checksum if its text changes.
Build arguments can override `PNPM_VERSION`, `PNPM_SHA256`, and
`PNPM_LICENSE_SHA256`. A version override requires the chosen target archive's
checksum; the pinned license checksum is reused unless explicitly overridden.
Both downloads must pass checksum verification before extraction and packaging.

See [image builds](../../../.github/IMAGE-BUILDS.md) for the build and publishing
workflows.
