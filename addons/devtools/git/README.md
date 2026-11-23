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

# Git addon

[Containerfile](Containerfile) builds Git from source on Alpine and packages
statically linked musl binaries, including the HTTP/HTTPS helpers, Git templates,
and a CA certificate bundle. The same image works with glibc and musl bases.
The workflows publish it as `ghcr.io/openkaiden/openshell-build-image-addons-git:next`.
The build uses Alpine's default `x86-64` and `armv8-a` CPU baselines without
`-march=native`. A minimum supported Linux kernel has not yet been established.

Copy the addon files into your base image and carry over its environment:

```Dockerfile
COPY --from=ghcr.io/openkaiden/openshell-build-image-addons-git:next / /
ENV PATH=/usr/local/bin:${PATH}
ENV GIT_SSL_CAINFO=/usr/local/share/git/ca-certificates.crt
```

Set `GIT_SSL_CAINFO` to your own CA bundle if you need custom trust roots. The
base image must provide `/bin/sh` and standard shell utilities for Git's shell
commands and hooks, plus `ssh` for SSH remotes and `git-lfs` for Git LFS. Perl,
Python, Tcl/Tk tools, iconv encoding conversions, and translations are omitted.
DNS resolution and SSH still use runtime configuration from the base image or
container runtime.

The private libcurl build includes HTTP/2, proxies, and gzip support, and omits
optional internationalized hostname, public-suffix, Brotli, and Zstandard support.
Git, libcurl, the other static libraries, and the bundled certificates require
image rebuilds for updates.

Git 2.56.1 passed compatibility tests with native ARM64 and emulated amd64 on:

| Base image | Libc |
| --- | --- |
| Alpine 3.24.2 | musl |
| UBI 9 | glibc 2.34 |
| UBI 10 (RHEL 10.3) | glibc 2.39 |

The checks covered commits, regular expressions, hooks, local clones, submodules,
archives, repository integrity, HTTPS queries and clones, and rejection of a
missing CA bundle. HTTPS queries also passed directly from scratch on both
architectures. These tests used Linux 7.1.3; older kernels and older physical
processors have not been validated. The build rejects ELF executables requiring
a dynamic loader or shared libraries.

Git and curl license texts are packaged. Additional dependency notices,
corresponding-source distribution, and license compatibility review remain to be
completed before redistribution.

See [image builds](../../../.github/IMAGE-BUILDS.md) for the build and publishing
workflows.
