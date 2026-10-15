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

# Addons for OpenShell-build-image

This repository builds addon images for various agents. Each addon image is an
OCI index with a separate image for every supported architecture and libc. The
index descriptors use `ai.openkaiden.openshell-build-image.libc` to identify the
libc; each selected image contains only its own files and environment settings.

## Inspect the published index

This example uses the Codex image published from `main` under the `next` tag:

```sh
ADDON_INDEX=ghcr.io/feloy/openshell-build-image-addons-codex:next

podman manifest inspect "$ADDON_INDEX" | jq -r '
  .manifests[] |
  [.platform.os + "/" + .platform.architecture,
   .annotations["ai.openkaiden.openshell-build-image.libc"],
   .digest] | @tsv
'
```

The index has `linux/amd64` and `linux/arm64` descriptors for both `glibc` and
`musl`. To get exactly the `linux/amd64` and `glibc` image digest:

```sh
podman manifest inspect "$ADDON_INDEX" | jq -r \
  --arg arch amd64 --arg libc glibc '
  [.manifests[] |
    select(.platform.os == "linux" and
           .platform.architecture == $arch and
           .annotations["ai.openkaiden.openshell-build-image.libc"] == $libc) |
    .digest] |
  if length == 1 then .[0] else error("expected exactly one matching addon image") end
'
```

For the `main` build at commit `7ffc10a`, the result is
`sha256:037b9b45a992c6825b3c8c210819279bb4ec1e24af92abd95d705efb8abc2c15`.
Using that descriptor digest selects the image itself, so a build does not need
the other architecture or libc payloads. The `next` tag can move, so inspect it
again to get the digest for a later build.

## Copy the selected image into a base image

Create a `Containerfile` with the amd64/glibc base image you want to extend.
This example uses UBI 10 and the digest above:

```Dockerfile
FROM registry.access.redhat.com/ubi10/ubi:latest

COPY --from=ghcr.io/feloy/openshell-build-image-addons-codex@sha256:037b9b45a992c6825b3c8c210819279bb4ec1e24af92abd95d705efb8abc2c15 / /

ENV CODEX_PATH=/usr/local/bin/codex
ENV PATH=/usr/local/bin:${PATH}
```

Build it for the architecture selected from the index:

```sh
podman build --platform linux/amd64 -t codex-example -f Containerfile .
```

`COPY` transfers the selected image's files, but does not transfer its `ENV`
settings. Set the environment needed by the addon in the final image. For an
addon index without libc annotations, copy all files from the image root; such
an image may be intended for a single libc.

See [.github/README.md](.github/README.md) for the build and publishing workflows.
