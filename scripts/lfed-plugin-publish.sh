#!/usr/bin/env bash
# Publish one lfed plugin version to ghcr.io as an OCI artifact.
#
#   scripts/lfed-plugin-publish.sh <dist-dir> <repository> <version> <revision>
#
#   dist-dir    GoReleaser output: lfed-<name>_<version>_<os>_<arch>.tar.gz
#   repository  ghcr.io/lf-certification/lfed-cli-plugins/<name>
#   version     X.Y.Z (the OCI tag; no v prefix)
#   revision    commit sha recorded in the index annotations
#
# Layout (the lfed CLI reads it; see internal/pluginmgr/oci.go in
# github.com/LF-Certification/lfed-cli):
#   <repository>:<version>                OCI index, annotations below
#   <repository>:<version>_<os>_<arch>    one platform manifest each (also
#                                         referenced by the index)
#     artifactType ARTIFACT_TYPE; config CONFIG_MEDIA_TYPE with the plugin
#     manifest JSON from `__metadata`; one layer: the GoReleaser archive
#     as LAYER_MEDIA_TYPE
#
# The plugin manifest comes from the linux/amd64 binary's `__metadata`. The
# same JSON is the config blob of every platform manifest, and its name,
# version and requires_lfed are the index annotations. The lfed CLI rejects
# an index whose annotations differ from the config. The script refuses to
# overwrite an existing version tag: only a registry "not found" answer
# counts as absent, and any other fetch error stops the script. The lfed
# CLI reads org.opencontainers.image.version from the index to check the
# signer identity; keep that annotation.
#
# The last stdout line is `index_digest=sha256:...`, the digest of the
# index. When GITHUB_OUTPUT is set, the script appends the same line there.
# The release workflow signs that digest with cosign.
#
# Needs `oras` (>= 1.3, for `oras manifest index create`) and `jq`; the
# registry login comes from the Docker config. PLAIN_HTTP=1 talks to a local
# http registry (tests).
set -euo pipefail

ARTIFACT_TYPE="application/vnd.linuxfoundation.ed.cli.plugin.v1"
CONFIG_MEDIA_TYPE="application/vnd.linuxfoundation.ed.cli.plugin.config.v1+json"
LAYER_MEDIA_TYPE="application/vnd.linuxfoundation.ed.cli.plugin.layer.v1.tar+gzip"
ANNOTATION_PREFIX="org.linuxfoundation.ed.cli.plugin"
SOURCE_URL="https://github.com/LF-Certification/lfed-cli-plugin-monkeysay"

die() { echo "lfed-plugin-publish: $*" >&2; exit 1; }
[ $# -eq 4 ] || die "usage: $0 <dist-dir> <repository> <version> <revision>"
dist="$1" repo="$2" version="$3" revision="$4"
command -v oras >/dev/null || die "oras is required"
command -v jq >/dev/null || die "jq is required"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version $version is not X.Y.Z"

name="${repo##*/}"
oras_flags=()
[ "${PLAIN_HTTP:-}" = "1" ] && oras_flags=(--plain-http)
binary="lfed-${name}"

if existing="$(oras manifest fetch "${oras_flags[@]}" --descriptor "${repo}:${version}" 2>&1)"; then
    die "${repo}:${version} already exists; a published version is immutable"
elif [[ "$existing" != *": not found" ]]; then
    die "cannot check whether ${repo}:${version} exists: ${existing}"
fi

# The plugin manifest from the linux/amd64 build. The workflow runs on
# linux/amd64.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
linux_archive="${dist}/${binary}_${version}_linux_amd64.tar.gz"
[ -f "$linux_archive" ] || die "missing ${linux_archive}"
tar -xzf "$linux_archive" -C "$work" "$binary"
"${work}/${binary}" __metadata > "${work}/manifest.json"
metadata="$(cat "${work}/manifest.json")"
schema="$(jq -r .schema_version <<<"$metadata")"
manifest_name="$(jq -r .name <<<"$metadata")"
manifest_version="$(jq -r .version <<<"$metadata")"
requires="$(jq -r .requires_lfed <<<"$metadata")"
[ "$schema" = "1" ] || die "binary reports manifest schema_version ${schema}, expected 1"
[ "$manifest_name" = "$name" ] || die "binary reports plugin ${manifest_name}, repository is ${name}"
[ "$manifest_version" = "$version" ] || die "binary reports version ${manifest_version}, tag is ${version}"
[ -n "$requires" ] && [ "$requires" != "null" ] || die "binary reports no requires_lfed"

created="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
# Each platform manifest gets its own tag, <version>_<os>_<arch>. ghcr.io
# does not reliably keep an untagged manifest long enough for the index
# step to find it by digest. The underscore keeps the tag out of the lfed
# CLI's version listing, which only reads semver tags.
#
# `oras push` cannot set a platform next to a custom config, and
# `oras manifest index create` reads the platform from image configs only.
# The script builds the index JSON itself: one descriptor per platform
# manifest, each with its os and architecture.
descriptors=()
for archive in "${dist}/${binary}_${version}_"*.tar.gz; do
    platform="$(basename "$archive" .tar.gz)"
    platform="${platform#"${binary}_${version}_"}"      # linux_amd64
    os="${platform%_*}" arch="${platform#*_}"
    tag="${version}_${os}_${arch}"
    echo "pushing ${os}/${arch} as ${repo}:${tag}..."
    (cd "$(dirname "$archive")" && oras push "${oras_flags[@]}" "${repo}:${tag}" \
        --artifact-type "$ARTIFACT_TYPE" \
        --config "${work}/manifest.json:${CONFIG_MEDIA_TYPE}" \
        --annotation "org.opencontainers.image.created=${created}" \
        "$(basename "$archive"):${LAYER_MEDIA_TYPE}")
    descriptors+=("$(oras manifest fetch "${oras_flags[@]}" --descriptor "${repo}:${tag}" |
        jq -c --arg os "$os" --arg arch "$arch" --arg type "$ARTIFACT_TYPE" \
            '{mediaType, digest, size, artifactType: $type, platform: {os: $os, architecture: $arch}}')")
done
[ ${#descriptors[@]} -gt 0 ] || die "no archives matching ${binary}_${version}_*.tar.gz in ${dist}"

echo "creating index ${repo}:${version}..."
jq -n \
    --arg type "$ARTIFACT_TYPE" \
    --arg version "$version" --arg source "$SOURCE_URL" --arg revision "$revision" \
    --arg created "$created" --arg name "$name" --arg requires "$requires" \
    --arg prefix "$ANNOTATION_PREFIX" \
    --slurpfile manifests <(printf '%s\n' "${descriptors[@]}") \
    '{
        schemaVersion: 2,
        mediaType: "application/vnd.oci.image.index.v1+json",
        artifactType: $type,
        manifests: $manifests,
        annotations: {
            "org.opencontainers.image.version": $version,
            "org.opencontainers.image.source": $source,
            "org.opencontainers.image.revision": $revision,
            "org.opencontainers.image.created": $created,
            ($prefix + ".name"): $name,
            ($prefix + ".requires_lfed"): $requires
        }
    }' > "${work}/index.json"
oras manifest push "${oras_flags[@]}" "${repo}:${version}" \
    --media-type application/vnd.oci.image.index.v1+json "${work}/index.json"

index_digest="$(oras manifest fetch "${oras_flags[@]}" --descriptor "${repo}:${version}" | jq -r .digest)"
[[ "$index_digest" =~ ^sha256:[0-9a-f]{64}$ ]] || die "unexpected index digest '${index_digest}' for ${repo}:${version}"

echo "published ${repo}:${version} (${#descriptors[@]} platforms, requires lfed ${requires})"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "index_digest=${index_digest}" >> "$GITHUB_OUTPUT"
fi
echo "index_digest=${index_digest}"
