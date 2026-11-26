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

# Addon build conventions

**Request for comments (RFC) for issue #16.** CI currently builds the checked-in
Containerfiles.

Each `addons/<category>/<addon>/addon.yaml` describes one addon. These conventions
specify how to generate its Containerfiles. The repository root is the build
context for every `COPY`.

## Builder

1. The CLI emits the catalog image selected by `from` as the stage named
   `builder`. It emits the builder's `env` entries as Containerfile `ENV`
   instructions, switches to root, and installs the packages listed inline in
   the addon's `packages` field using the image's package manager. Each selected
   tool contributes its `env` values to the builder before its install steps.
2. The CLI switches to `USER 65532` for the addon's build steps.
3. When the addon directory contains `install.sh`, the CLI copies it to
   `/tmp/install.sh` with mode `0755` and runs it once per build as UID 65532.
   The shebang selects the interpreter. The installer writes the files to ship
   under `/tmp/rootfs/`. By default it receives zero arguments. Each string in
   `install_args` supplies one literal argument. For example, pnpm's musl
   variant sets `install_args: [musl]`.
4. After the installer, the CLI emits the common `builder.instructions`, then
   the selected variant's `instructions`. Claude and Codex use the common
   instructions to copy and run the shared ACP build script. Each addon sets
   `ACP_OUTPUT` to the name of its adapter. An addon
   without an installer can populate `/tmp/rootfs/` directly in its instructions.

## Final image

The CLI emits these two instructions for every addon.

```Dockerfile
FROM scratch
COPY --from=builder /tmp/rootfs/ /
```

It then emits `final.instructions` followed by `final.env`. Node 24 uses a
final-stage `ADD` to include its license. The builder's UID and environment
are scoped to the builder stage.

## Variants and catalogs

Omit `builder.variants` for one libc-independent recipe. Otherwise each key in
`builder.variants` names an output libc. A variant can override `from`,
`packages`, `tools`, or `install_args`. Its `env` entries extend or override
common entries by name. Every `env` entry supplies a literal string value
directly, including versions and checksums. Omit variables whose values the
installer selects for the target. The builder image and target libc are
independent. Both pnpm variants download their binaries on Alpine.

- Each builder image has a tag, a digest used for the build, and a package manager. [Image catalog](catalog/images.yaml)
- The tool catalog specifies how to install shared tools. [Tool catalog](catalog/tools.yaml)

## Updating shared scripts

Update Bun's release tag and installer URL in [install-bun.sh](scripts/install-bun.sh).
Update ACP repository URLs, release tags, and commit SHAs in [build-acp.sh](scripts/build-acp.sh).
The configuration block at the top of the script holds a separate tag and SHA
for Claude and Codex. Update the pair for the adapter being released.
