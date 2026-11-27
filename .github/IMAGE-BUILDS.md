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

Pull requests build one OCI image index per addon, with `linux/amd64` and
`linux/arm64` images. Addons with libc-specific files have a separate pair of
images for each configured libc. Addons that work with either libc have just one
pair, without libc annotations.

The `pull_request.paths` list in [pr-check.yaml](workflows/pr-check.yaml) triggers
checks for changes to addon Containerfiles, installers, manifests, inventories,
shared helpers, build workflows, or context ignore files. Documentation-only
changes do not trigger it. An addon-specific change selects that addon. Changes
to `scripts/install-bun.sh` or `scripts/build-acp.sh` select Claude and Codex.
Changes to shared build or verification tooling and context ignore files select
all addons. Each selected addon builds its complete index, including all
supported architectures and libc variants.
When adding a shared dependency, update both the trigger paths and the path
selection in [image-matrix.yaml](workflows/image-matrix.yaml).

## Verify an addon

Before publishing a PR preview or a `main` build, the Linux jobs compare every
addon variant with its checked-in `inventory.json`. Each path maps to `null` for
a regular file or to a string for a symlink target. The `common` mapping applies
to every variant. Entries in `variants` are keyed by architecture, with a libc
suffix for libc-specific addons. Declare each path either in `common` or in the
applicable variants. Paths and symlink targets use UTF-8.

CI uses the latest stable release of `openshell-build-image` to apply the
freshly built index to each digest-pinned base in `verification.baseImages` on
both architectures. It checks that the target filesystem contains the addon
payload and that other base entries match. For directories in both the base and
addon, the target may retain either source's ownership and permissions. CI then
runs `verification.commands` inside the target image with networking disabled.

To refresh an inventory after an intentional payload change, build the addon
index with [build-addon-index.sh](scripts/build-addon-index.sh) on Linux. For
example, use the following commands for GitHub CLI and review the inventory
diff before committing.

```bash
(
  set -e
  work=$(mktemp -d)
  trap 'rm -rf -- "$work"' EXIT
  run_id=${work##*/}
  export IMAGE_NAME="localhost/addon-check-github-cli-${run_id,,}"
  export BUILD_CONTEXT=.
  export VARIANTS_JSON='[{"containerfile":"addons/devtools/github-cli/Containerfile"}]'

  .github/scripts/build-addon-index.sh
  bash .github/scripts/verify-addon.sh inventory "${IMAGE_NAME}:next" > "$work/inventory.json"
  mv "$work/inventory.json" addons/devtools/github-cli/inventory.json
)
```

## Publish verified images

After a successful PR check, a separate workflow publishes the image artifacts to
`ghcr.io/<owner>/<repository>-<addon>/pr:<head-sha>`, including every architecture
and libc descriptor and provenance attestations. A preview check on the PR shows
each image reference.
This also works for fork PRs: the build uploads artifacts with read-only permissions,
and the publishing workflow copies the images without executing PR code.
The publishing workflow must exist on the default branch to receive `workflow_run`
events.

Pushes to `main` use the same addon selection rules, comparing the commits before
and after the entire push. Each selected addon index is published to
`ghcr.io/<owner>/<repository>-<addon>` with `next` and commit-SHA tags, plus
provenance attestations. If no build inputs changed, publishing is skipped.
Unchanged addons keep their existing tags; they do not get a tag for the new
commit. Manual runs rebuild and publish all addons, as do pushes whose previous
commit is unavailable (for example, when creating the branch).

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
When the set of variants changes, update `verification.baseImages` and regenerate
`inventory.json` for each affected addon.
For each configured libc, discovery looks for
`addons/<category>/<addon>/Containerfile.<libc>`.
The default configuration builds these descriptors for a libc-specific addon:

| Platform | Libc annotation | Containerfile |
| --- | --- | --- |
| `linux/amd64` | `glibc` | `addons/<category>/<addon>/Containerfile.glibc` |
| `linux/arm64` | `glibc` | `addons/<category>/<addon>/Containerfile.glibc` |
| `linux/amd64` | `musl` | `addons/<category>/<addon>/Containerfile.musl` |
| `linux/arm64` | `musl` | `addons/<category>/<addon>/Containerfile.musl` |

Each libc-specific descriptor has an `ai.openkaiden.openshell-build-image.libc`
annotation on the index entry. Its image contains only that libc's files and its
own `ENV` settings. A consumer should inspect the index, match both the base image's
architecture and libc, and use the matching descriptor digest in its generated
build. It should copy the selected image's `ENV` settings into the final image
as well as its files, and fail if the index has libc annotations but no matching
entry.

For an addon that works with either libc, provide a plain
`addons/<category>/<addon>/Containerfile` instead. Discovery builds it once per
architecture, and the index entries omit the libc annotation. For example,
`addons/devtools/github-cli/Containerfile` packages the statically linked `gh`
binary in this format. Do not combine a plain Containerfile with libc-specific
Containerfiles in the same addon directory.

For addon indexes without libc annotations, consumers select by platform and copy
all files from the selected image root. This also supports images intended for a
single libc.

The build context is the repository root, so each Containerfile can copy shared
helpers from `scripts/` and its own installer from
`addons/<category>/<addon>/`. For example, the Codex Containerfiles use
`COPY addons/agents/codex/install.sh /tmp/install-agent.sh`. For a new addon,
place its Containerfiles, installer, and [addon.yaml](../README.md#addon-catalog-metadata)
under a category. Include the `verification` block in `addon.yaml` and check in
the [generated inventory](#verify-an-addon) beside it.

The presence of `Containerfile.<libc>` declares support for that libc. Variants
without a Containerfile are skipped with a notice. Each addon builds
independently, so one failed build does not cancel the others.

To update Claude Code, Codex, OpenCode, Git, GitHub CLI, or pnpm, edit the
release version and any associated checksums in the configuration block at the
top of `addons/<category>/<addon>/install.sh`. Update `metadata.version` in the
addon's `addon.yaml` when changing the packaged version.

Bun's release tag and installer URL live in `scripts/install-bun.sh`.
Each ACP adapter's release tag and expected commit SHA live in
`scripts/build-acp.sh`, which also constructs its repository URL.
Claude and Codex select their adapter by name after the agent installer runs.
The checked-in Containerfiles accept build arguments for one-off ACP version
and commit SHA overrides.
Addons sourced from existing images pin their versions and image digests in
their Containerfiles. Update `metadata.version` alongside those pins.
