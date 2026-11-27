#!/usr/bin/env bash
#
# Copyright (C) 2026 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

annotation=ai.openkaiden.openshell-build-image.libc
registry_image=docker.io/library/registry@sha256:82f6ff4a7f982960c8aa51617fea3aabc485df6e55cce80d22deb1de36f1bc3c
script=$(realpath "${BASH_SOURCE[0]}")

fail() {
  printf '%s\n' "$*" >&2
  exit 1
}

# Mount an image and record metadata, file checksums, and symlink targets.
scan_image() (
  local image=$1 root= scratch
  scratch=$(mktemp -d)
  trap 'cd /; if [[ -n $root ]]; then podman image unmount "$image" >/dev/null; fi; rm -rf -- "$scratch"' EXIT
  root=$(podman image mount "$image")
  cd "$root"
  # Keep paths and symlink targets NUL-delimited, and never follow symlinks.
  find . -mindepth 1 -printf '%P\0%y\0%m\0%U\0%G\0%l\0' > "$scratch/entries"
  find . -type f -print0 | xargs -0r sha256sum --zero -- > "$scratch/hashes"
  # jq replaces invalid UTF-8, which could hide a path or symlink mismatch.
  iconv -f UTF-8 -t UTF-8 "$scratch/entries" "$scratch/hashes" >/dev/null ||
    fail "$image contains a path or symlink target with invalid UTF-8"
  jq -n --rawfile entries "$scratch/entries" --rawfile hashes "$scratch/hashes" '
    ($hashes | split("\u0000") | map(select(length > 0) |
      {key: .[67:], value: .[:64]}) | from_entries) as $sha256 |
    ($entries | split("\u0000")) as $fields |
    reduce range(0; ($fields | length); 6) as $i ({};
      if $fields[$i] == "" then . else
        ("/" + $fields[$i]) as $path |
        $fields[$i + 1] as $type |
        .[$path] = {
          type: $type, mode: $fields[$i + 2],
          uid: ($fields[$i + 3] | tonumber), gid: ($fields[$i + 4] | tonumber),
          value: (if $type == "f" then $sha256[$path]
                  elif $type == "l" then $fields[$i + 5]
                  else null end)
        }
      end)
  '
)

# Root can mount the image directly. Rootless Podman needs its user namespace
# to get the required mount permissions.
snapshot() {
  if (( EUID == 0 )); then
    scan_image "$1"
  else
    podman unshare bash "$script" scan "$1"
  fi
}

# Capture both the full snapshot and the inventory entries for each variant.
collect_payloads() {
  local variant source
  while IFS= read -r variant; do
    source="${index%:*}:$variant"
    printf 'Inspecting addon variant %s\n' "$source" >&2
    snapshot "$source" > "$work/$variant.snapshot.json"
    jq -S '
      with_entries(
        select(.value.type != "d") |
        .value |= if .type == "l" then .value
                  elif .type == "f" then null
                  else error("unexpected file type " + .type) end
      )
    ' "$work/$variant.snapshot.json" > "$work/$variant.files.json"
  done < <(jq -r '.[]' "$work/variants.json")
}

# Write shared entries once and group the remaining entries by variant.
write_inventory() {
  local variant
  while IFS= read -r variant; do
    jq --arg variant "$variant" '{($variant): .}' "$work/$variant.files.json"
  done < <(jq -r '.[]' "$work/variants.json") |
    jq -sS '
      add as $variants |
      ($variants | to_entries[0].value | with_entries(
        . as $file | select(all($variants[];
          has($file.key) and .[$file.key] == $file.value))
      )) as $common |
      {common: $common, variants: ($variants | map_values(with_entries(
        .key as $path | select($common | has($path) | not)
      )))}
    '
}

# Check each variant's files and symlink targets against the inventory.
check_inventory() {
  local checked_in=$1 variant issues
  jq -e --slurpfile variants "$work/variants.json" '
    (.common | type == "object") and
    (.variants | keys == ($variants[0] | sort)) and
    (all(.variants[]; type == "object"))
  ' "$checked_in" > /dev/null || fail "Inventory does not cover the variants in $index"
  issues=$(jq -r '
    .common as $common |
    .variants | to_entries[] as $variant |
    ($variant.value | keys[]) as $path |
    select($common | has($path)) |
    "\($variant.key): \($path)"
  ' "$checked_in")
  [[ -z $issues ]] || fail "Inventory paths listed in both common and a variant:"$'\n'"$issues"
  while IFS= read -r variant; do
    issues=$(jq -r --arg variant "$variant" --slurpfile actual "$work/$variant.files.json" '
      (.common + .variants[$variant]) as $expected |
      $actual[0] as $actual |
      (($expected | keys[]) as $path |
        if ($actual | has($path) | not) then "missing file: \($path)"
        elif $expected[$path] != $actual[$path] then
          "incorrect file type or symlink target: \($path) (expected \($expected[$path]|tojson), got \($actual[$path]|tojson))"
        else empty end),
      (($actual | keys[]) as $path |
        select($expected | has($path) | not) | "unexpected file: \($path)")
    ' "$checked_in")
    [[ -z $issues ]] || fail "$variant inventory differs from the addon payload:"$'\n'"$issues"
  done < <(jq -r '.[]' "$work/variants.json")
}

# Confirm the target contains the addon files and preserves other base entries.
check_target() {
  local variant=$1 base=$2 target=$3 issues
  snapshot "$base" > "$work/base.json"
  snapshot "$target" > "$work/target.json"
  issues=$(jq -nr --slurpfile before "$work/base.json" --slurpfile after "$work/target.json" \
    --slurpfile addon "$work/$variant.snapshot.json" '
      $before[0] as $base | $after[0] as $target | $addon[0] as $source |
      ($source | with_entries(select(.value.type != "d"))) as $payload |
      (($payload | keys[]) as $path |
        if ($target | has($path) | not) then "missing addon file: \($path)"
        elif $target[$path] != $payload[$path] then "file differs from addon payload: \($path)"
        else empty end),
      ((($base + $target) | keys[]) as $path |
        select(($payload | has($path) | not) and $base[$path] != $target[$path]) |
        select(($base | has($path)) or $target[$path].type != "d") |
        # COPY can apply the metadata from the addon to a shared directory.
        select($source[$path].type != "d" or $source[$path] != $target[$path]) |
        "unexpected filesystem change: \($path)")
  ')
  [[ -z $issues ]] || fail "$variant target image differs from the expected filesystem:"$'\n'"$issues"
}

# Run each declared command in a fresh offline container with a timeout.
check_commands() {
  local arch=$1 target=$2 name="addon-command-${work##*.}" entry
  local -a argv
  while IFS= read -r entry; do
    mapfile -d '' -t argv < <(jq -jr '.[] | ., "\u0000"' <<< "$entry")
    printf 'Running'
    printf ' %q' "${argv[@]}"
    printf '\n'
    if ! timeout --kill-after=5s 30s podman run --rm --name "$name" --pull=never \
      --platform "linux/$arch" --network none --ulimit core=0:0 --entrypoint "${argv[0]}" \
      "$target" "${argv[@]:1}" </dev/null; then
      podman rm --force --ignore --time 0 "$name" >/dev/null
      fail "Command failed in $target: $entry"
    fi
  done < <(jq -c '.verification.commands[]' "$work/manifest.json")
}

# Build and verify the target for one base image and architecture.
check_image() (
  local arch=$1 libc=$2 image=$3 variant=$4 base target
  target="localhost/addon-verification:${work##*.}-$arch-$libc"
  trap 'podman image rm --ignore "$target" >/dev/null' EXIT
  printf 'Verifying linux/%s on %s (%s)\n' "$arch" "$image" "$libc"
  # A pinned index reference is shared by both architectures. Pass the image
  # ID printed by this pull to make the builder use the requested platform.
  base=$(podman pull --quiet --platform "linux/$arch" "$image")
  [[ $(podman image inspect --format '{{.Os}}/{{.Architecture}}' "$base") == "linux/$arch" ]] ||
    fail "$image did not resolve to linux/$arch"
  "$builder" --runtime podman --from "$base" --addon "$registry_ref" "$target"
  [[ $(podman image inspect --format '{{.Os}}/{{.Architecture}}' "$target") == "linux/$arch" ]] ||
    fail "$target was built for the wrong platform"
  check_target "$variant" "$base" "$target"
  check_commands "$arch" "$target"
)

# Validate the manifest and serve the exported OCI index to the builder.
verify() {
  local manifest=$1 inventory endpoint arch libc image variant
  yq -o=json '.' "$manifest" > "$work/manifest.json"
  inventory=$(jq -er '.verification.inventory | select(. == "inventory.json")' "$work/manifest.json") ||
    fail "Expected verification.inventory to reference inventory.json in $manifest"
  jq -e '
    .verification |
    (.baseImages | length > 0 and all(.[];
      (.image | test("@sha256:[a-f0-9]{64}$")) and (.libc | test("^[a-z0-9][a-z0-9._-]*$")))) and
    (.commands | length > 0 and all(.[]; type == "array" and length > 0 and
      (.[0] | startswith("/")) and all(.[]; type == "string" and (contains("\u0000") | not))))
  ' "$work/manifest.json" > /dev/null || fail "Invalid verification images or commands in $manifest"
  check_inventory "$(dirname "$manifest")/$inventory"
  jq -en --slurpfile variants "$work/variants.json" --slurpfile manifest "$work/manifest.json" '
    ($variants[0] | map(split("-")[1:] | join("-")) | unique) as $available |
    ($manifest[0].verification.baseImages | map(.libc) | unique) as $tested |
    $available == [""] or $available == $tested
  ' >/dev/null || fail "Verification bases do not cover the libc variants in $index"

  registry_id=$(podman run --detach --rm --publish 127.0.0.1::5000 "$registry_image")
  endpoint=$(podman port "$registry_id" 5000/tcp)
  for ((attempt = 0; attempt < 30; attempt++)); do
    if curl --noproxy 127.0.0.1 --max-time 2 --fail --silent "http://$endpoint/v2/" >/dev/null; then
      break
    fi
    sleep 1
  done
  if (( attempt == 30 )); then
    podman logs "$registry_id"
    fail "Registry at $endpoint did not start"
  fi
  registry_ref="$endpoint/addon:verify"
  skopeo copy --all --preserve-digests --dest-tls-verify=false "$oci_source" "docker://$registry_ref"
  while IFS=$'\t' read -r libc image; do
    for arch in amd64 arm64; do
      variant=$arch
      if jq -e --arg variant "$arch-$libc" 'index($variant) != null' "$work/variants.json" >/dev/null; then
        variant="$arch-$libc"
      fi
      check_image "$arch" "$libc" "$image" "$variant"
    done
  done < <(jq -r '.verification.baseImages[] | [.libc, .image] | @tsv' "$work/manifest.json")
}

# Remove the temporary registry and working files when verification exits.
cleanup() {
  if [[ -n $registry_id ]]; then
    podman rm --force --ignore "$registry_id" >/dev/null
  fi
  rm -rf -- "$work"
}

[[ $(uname -s) == Linux ]] || fail "Addon verification requires Linux"
case ${1:-} in
  scan) scan_image "$2"; exit ;;
  inventory) [[ $# == 2 ]] || fail "Usage: $0 inventory INDEX" ;;
  check) [[ $# == 5 ]] || fail "Usage: $0 check INDEX ADDON_YAML BUILDER OCI_SOURCE" ;;
  *) fail "Usage: $0 inventory INDEX | check INDEX ADDON_YAML BUILDER OCI_SOURCE" ;;
esac

index=$2
work=$(mktemp -d)
registry_id=
trap cleanup EXIT
podman manifest inspect "$index" | jq -e --arg annotation "$annotation" '
  [.manifests[] |
    select(.platform.os == "linux") |
    .platform.architecture + ((.annotations[$annotation] // "") |
      if length > 0 then "-" + . else "" end)
  ] | sort | select(length > 0)
' > "$work/variants.json"
collect_payloads
if [[ $1 == inventory ]]; then
  write_inventory
else
  builder=$4
  oci_source=$5
  verify "$3"
fi
