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

Pull requests build every available addon image for `linux/amd64` and `linux/arm64`.
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

Each directory under `agents/` represents an agent. Discovery builds
`agents/<agent>/Containerfile` into one image with the suffix `<agent>`.
The build context is `agents/<agent>/`. Add a directory with its Containerfile
and build context files to enable a new agent automatically in both workflows.
Directories without a Containerfile are skipped with a notice.
Each agent builds independently, so one failed build does not cancel the others.

Each addon image can contain payloads for any number of libc variants. For
each variant, its Containerfile adds a label named
`ai.openkaiden.openshell-build-image.libc.<variant>` whose value is the absolute
directory containing that variant's files. A consumer reads the label for its
libc and copies the files from that directory into its base image. Variant
names and directories are defined by the addon, not by the build workflow.

If an image has no `ai.openkaiden.openshell-build-image.libc.*` labels at all,
the consumer copies all files from the image root.

If an image has any libc labels but none matches the base image's libc, the
consumer reports an error.

The final addon image can also declare environment variables for the resulting
base image. The consumer reads `config.Env` from the same platform image used
for the files and applies those values after copying the selected payload.
Copying files alone does not transfer image environment settings. When applying
`PATH`, retain the base image's existing entries and add any missing addon
entries instead of replacing the entire value.

The current Claude and Codex images provide `glibc` and `musl` payloads. Their
labels point to `/glibc` and `/musl` respectively; these paths are examples,
not required names for future variants. To add a variant, add a build stage,
copy its payload into the final image, and label the chosen directory in the
agent's Containerfile.
