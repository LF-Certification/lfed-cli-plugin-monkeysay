#!/usr/bin/env bash
set -euo pipefail

# Release in two steps.
#
#   scripts/create-release.sh [--dry-run]
#       Writes CHANGELOG.md for the next version and commits it. The next
#       version comes from the Conventional Commits since the last tag.
#       Push the commit, or open a pull request when main is protected.
#
#   scripts/create-release.sh tag
#       Run on the merged commit: tags HEAD with the version at the top of
#       CHANGELOG.md. HEAD MUST be on origin/main. Push with
#       `git push origin <tag>`. The vX.Y.Z tag runs release.yml.

CHANGELOG="CHANGELOG.md"

main() {
    local dry_run=false mode=changelog
    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run) dry_run=true ;;
            tag) mode=tag ;;
            *) die "usage: $0 [--dry-run] [tag]" ;;
        esac
        shift
    done

    case "$mode" in
        changelog) changelog "$dry_run" ;;
        tag) tag_head ;;
    esac
}

changelog() {
    local dry_run="$1"

    local next
    if [ -z "$(git tag -l "v*")" ]; then
        next="v${INITIAL_VERSION:-0.1.0}"
    else
        next=$(git cliff --bumped-version)
    fi
    [ -n "$next" ] || die "git-cliff did not propose a version"

    if [ "$dry_run" = true ]; then
        echo "Next version: $next"
        echo ""
        git cliff --unreleased --tag "$next" --strip header
        return 0
    fi

    git diff-index --quiet HEAD -- || die "the working tree has uncommitted changes"

    git cliff --tag "$next" --output "$CHANGELOG"
    git add "$CHANGELOG"
    git commit -m "chore(release): release $next"

    echo "Updated $CHANGELOG for $next."
    echo "Merge this commit into main, then run: $0 tag"
}

tag_head() {
    local version tag
    version=$(sed -n 's/^## \[\([0-9][^]]*\)\].*/\1/p' "$CHANGELOG" | head -n 1)
    [ -n "$version" ] || die "no version heading in $CHANGELOG"
    tag="v${version}"

    git diff-index --quiet HEAD -- || die "the working tree has uncommitted changes"
    git fetch -q origin main
    git merge-base --is-ancestor HEAD origin/main || die "HEAD is not on origin/main; check out the merged commit"
    [ -z "$(git tag -l "$tag")" ] || die "tag $tag exists"
    git tag "$tag" -m "Release $tag"

    echo "Created tag $tag on $(git rev-parse --short HEAD)."
    echo "Run 'git push origin $tag' to publish."
}

die() { echo "create-release.sh: $*" >&2; exit 1; }

main "$@"
