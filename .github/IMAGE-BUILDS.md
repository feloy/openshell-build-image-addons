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

# Image builds

Pull requests build one OCI image index per addon. Each configured libc has
separate `linux/amd64` and `linux/arm64` images in that index.
After a successful PR check, a separate workflow publishes the image artifacts to
`ghcr.io/<owner>/<repository>-<addon>/pr:<head-sha>`, including every architecture
and libc descriptor and provenance attestations. A preview check on the PR shows
each image reference.
This also works for fork PRs: the build uploads artifacts with read-only permissions,
and the publishing workflow copies the images without executing PR code.
The publishing workflow must exist on the default branch to receive `workflow_run`
events.

Pushes to `main` and manual runs also publish each addon index to
`ghcr.io/<owner>/<repository>-<addon>` with `next` and commit-SHA tags, plus
provenance attestations.

Addons are organized as `addons/<category>/<addon>/`. For example,
`addons/agents/codex/` contains the Codex agent addon. Categories are directories
directly under `addons/`; add other categories alongside `agents/` as needed.
Both the PR and main build workflows discover addons in every category.

The addon directory name determines the image suffix, so moving an addon into a
category keeps its published image name unchanged. Addon names must be unique
across categories; discovery fails if supported addons share a name.

Configure the space-separated libc variants in the top-level `env` block of
[image-matrix.yaml](workflows/image-matrix.yaml):

```yaml
env:
  LIBC_VARIANTS: glibc musl
```

Remove an entry to disable it, or add an entry to discover another variant.
For each configured libc, discovery looks for
`addons/<category>/<addon>/Containerfile.<libc>`.
The default configuration builds these descriptors in each addon index:

| Platform | Libc annotation | Containerfile |
| --- | --- | --- |
| `linux/amd64` | `glibc` | `addons/<category>/<addon>/Containerfile.glibc` |
| `linux/arm64` | `glibc` | `addons/<category>/<addon>/Containerfile.glibc` |
| `linux/amd64` | `musl` | `addons/<category>/<addon>/Containerfile.musl` |
| `linux/arm64` | `musl` | `addons/<category>/<addon>/Containerfile.musl` |

Each descriptor has an `ai.openkaiden.openshell-build-image.libc` annotation on
the index entry. Its image contains only that libc's files and its own `ENV`
settings. A consumer should inspect the index, match both the base image's
architecture and libc, and use the matching descriptor digest in its generated
build. It should copy the selected image's `ENV` settings into the final image
as well as its files, and fail if the index has libc annotations but no matching
entry.

For addon images without libc annotations, copy all files from the image root.
This also supports images intended for a single libc.

The build context is the repository root, so each Containerfile can copy shared
helpers from `scripts/` and its own installer from
`addons/<category>/<addon>/`. For example, the Codex Containerfiles use
`COPY addons/agents/codex/install.sh /tmp/install-agent.sh`. Add a directory with
its Containerfiles and installer under any category to enable a new addon
automatically in both workflows. The presence of `Containerfile.<libc>` declares
support for that libc. Variants without a Containerfile are skipped with a
notice. Each addon builds independently, so one failed build does not cancel
the others.

The version defaults are kept in `scripts/install-bun.sh` and each addon's
`install.sh`. Containerfile build arguments can override those defaults when
needed.
