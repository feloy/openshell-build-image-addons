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

This repository builds addon images organized by category under
`addons/<category>/<addon>/`. Agent addons live in `addons/agents/`, and developer
tools live in `addons/devtools/`. New categories are discovered automatically.
Each addon image is an OCI index with a separate image for every supported
architecture. Addons with libc-specific files also have separate images for each
libc, identified by the `ai.openkaiden.openshell-build-image.libc` descriptor
annotation. Addons that work with either libc omit that annotation. Each selected
image contains only its own files and environment settings.

## Addon catalog metadata

Discover addons by reading `addons/<category>/<name>/addon.yaml`. Use the
directory names for the catalog's `category` and `name` fields. Each file
requires a top-level `apiVersion: v1`, which identifies the manifest format.
In `v1`, the top-level `metadata` mapping has three required, non-empty string
fields.

| Field | Meaning |
| --- | --- |
| `displayName` | Human-readable title shown in the catalog. |
| `description` | Short description of what the addon provides. |
| `version` | Upstream release of the primary tool packaged by the addon. |

`addon.yaml` is the source of truth for these fields. The Containerfiles and
installers define how to build the image. See the [Codex metadata](addons/agents/codex/addon.yaml).

The top-level `contents` mapping lists installed files, including executable
symlinks, and directories containing bundled files. All paths are absolute
inside the resulting container. Entries under `contents.variants` apply to the
named libc variant in addition to the common paths.

The top-level `verification` mapping describes how to check that the addon
works in a container. Each entry in `verification.baseImages` gives a
digest-pinned `image` reference and its `libc`. Apply the addon to a listed base
image and run `verification.commands` inside the resulting container. Each
command is an array with the executable path followed by its arguments.
`verification.inventory` points to the exact file list used by CI.

For the catalog's `image` field, use the published repository
`ghcr.io/openkaiden/openshell-build-image-addons-<name>` followed by `@` and the
digest of its OCI index. Consumers use that index to select their architecture
and libc variant.

## Inspect the published index

This example uses the Codex image published from `main` under the `next` tag:

```sh
ADDON_INDEX=ghcr.io/openkaiden/openshell-build-image-addons-codex:next

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

COPY --from=ghcr.io/openkaiden/openshell-build-image-addons-codex@sha256:037b9b45a992c6825b3c8c210819279bb4ec1e24af92abd95d705efb8abc2c15 / /

ENV CODEX_PATH=/usr/local/bin/codex
ENV PATH=/usr/local/bin:${PATH}
```

Build it for the architecture selected from the index:

```sh
podman build --platform linux/amd64 -t codex-example -f Containerfile .
```

`COPY` transfers the selected image's files, but does not transfer its `ENV`
settings. Set the environment needed by the addon in the final image. For an
addon index without libc annotations, select by architecture and copy all files
from the selected image root. Such addons can be independent of libc, like GitHub
CLI, or intended for a single libc.

See [.github/IMAGE-BUILDS.md](.github/IMAGE-BUILDS.md) for the build and publishing
workflows and how to add an addon or category.
