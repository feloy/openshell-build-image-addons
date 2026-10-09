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

Pull requests build every available image for `linux/amd64` and `linux/arm64`.
After a successful PR check, a separate workflow publishes the image artifacts to
`ghcr.io/<owner>/<repository>-<suffix>/pr:<head-sha>`, including both architectures
and provenance attestations. A preview check on the PR shows each image reference.
This also works for fork PRs: the build uploads artifacts with read-only permissions,
and the publishing workflow copies the images without executing PR code.
The publishing workflow must exist on the default branch to receive `workflow_run`
events.

Pushes to `main` and manual runs also publish each image to
`ghcr.io/<owner>/<repository>-<suffix>` with `next` and commit-SHA tags, plus
provenance attestations.

Each directory under `agents/` represents an agent. The directory name determines
the agent portion of the image suffix; any agent name can be used.

Configure the space-separated libc variants in the top-level `env` block of
[image-matrix.yaml](workflows/image-matrix.yaml):

```yaml
env:
  LIBC_VARIANTS: glibc musl
```

Remove an entry to disable it, or add an entry to discover another variant.
For each configured libc, discovery looks for `agents/<agent>/Containerfile.<libc>`
and uses the image suffix `<agent>-<libc>`. The default configuration builds:

| Image suffix | Containerfile |
| --- | --- |
| `<agent>-glibc` | `agents/<agent>/Containerfile.glibc` |
| `<agent>-musl` | `agents/<agent>/Containerfile.musl` |

The build context is `agents/<agent>/`. Add a directory with its Containerfiles
and build context files to enable a new agent automatically in both workflows.
Variants without a Containerfile are skipped with a notice.
Each variant builds independently, so one failed build does not cancel the others.
