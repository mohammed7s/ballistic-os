#!/bin/bash
# Check out GrapheneOS at the tag in MANIFEST, verify the manifest tag signature,
# sync the tree, apply patches/. Runs on the build box. Safe to re-run: repo init/sync
# resume, and patches already applied are skipped.
#
#   scripts/sync.sh [SRC_DIR]        (default SRC_DIR: ~/gos)
#
# Env: JOBS (default 8; 32 hit googlesource quota, RESOURCE_EXHAUSTED / HTTP 429).

set -o errexit -o nounset -o pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tag="$(tr -d '[:space:]' < "$here/MANIFEST")"
src="${1:-$HOME/gos}"
jobs="${JOBS:-8}"
signers="$HOME/.ssh/grapheneos_allowed_signers"
# GrapheneOS release signing key, from https://grapheneos.org/install/cli
expected_signer='contact@grapheneos.org ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIUg/m5CoP83b0rfSCzYSVA4cw4ir49io5GPoxbgxdJE'

mkdir -p "$src" "$(dirname "$signers")"
cd "$src"

curl -sSf https://grapheneos.org/allowed_signers > "$signers"
if [[ "$(tr -d '\n' < "$signers")" != "$expected_signer" ]]; then
    echo "allowed_signers from grapheneos.org does not match the pinned key; stopping" >&2
    exit 1
fi

# --depth=1: the release manifest pins every project to a commit hash, history is not needed
repo init -u https://github.com/GrapheneOS/platform_manifest.git -b "refs/tags/$tag" --depth=1 </dev/null

git -C .repo/manifests config gpg.ssh.allowedSignersFile "$signers"
git -C .repo/manifests verify-tag "$(git -C .repo/manifests describe)"
[[ "$(git -C .repo/manifests describe)" == "$tag" ]]

start=$(date +%s)
# --optimized-fetch: skip projects whose pinned commit is already present (cheap re-runs).
# If a run stalls on a full-history fetch of a large prebuilt (seen: prebuilts/tools,
# tools/tradefederation/prebuilts; repo drops --depth when it retries), stop it and fetch the
# pinned commit alone, then re-run this script:
#   git --git-dir=.repo/projects/<path>.git fetch --depth=1 --no-tags aosp <revision>
repo sync -c -j"$jobs" --no-tags --no-clone-bundle --retry-fetches=5 --optimized-fetch
echo "sync: $tag in $src, $(( $(date +%s) - start )) s"

# patches/<repo path with / replaced by _>/NNNN-*.patch, e.g. patches/frameworks_base/
shopt -s nullglob
for dir in "$here"/patches/*/; do
    project="$(basename "$dir" | tr _ /)"
    for patch in "$dir"*.patch; do
        if git -C "$project" apply --reverse --check "$patch" 2>/dev/null; then
            echo "already applied: $project $(basename "$patch")"
        else
            git -C "$project" am --3way "$patch"
        fi
    done
done
