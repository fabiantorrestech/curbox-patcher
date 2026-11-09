#!/usr/bin/env bash
# Moves the grayscale patch onto a new Curbox release and re-exports patches/grayscale.patch.
#
# Usage:  scripts/refresh-patch.sh <path to curbox-android checkout> <release tag, e.g. 7>
#
# The patch lives as ONE commit on branch patch/grayscale in the curbox-android checkout.
# If the rebase stops on a conflict: fix the files, `git add` them, `git rebase --continue`,
# then run this script again with the same arguments.
set -euo pipefail

CURBOX="${1:?path to curbox-android checkout}"
TAG="${2:?release tag, e.g. 7}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
UPSTREAM="https://github.com/curbox-app/curbox-android"
BRANCH="patch/grayscale"

cd "$CURBOX"

if [ -d "$(git rev-parse --git-path rebase-merge)" ] || [ -d "$(git rev-parse --git-path rebase-apply)" ]; then
  echo "A rebase is still in progress in $CURBOX. Finish it first (git rebase --continue)." >&2
  exit 1
fi
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  echo "$CURBOX has uncommitted changes. Commit or stash them first." >&2
  exit 1
fi

git fetch --quiet "$UPSTREAM" "refs/tags/$TAG:refs/tags/$TAG"
git switch --quiet "$BRANCH"

if [ "$(git rev-parse HEAD~1)" != "$(git rev-parse "refs/tags/$TAG^{commit}")" ]; then
  echo "Rebasing $BRANCH onto Curbox $TAG..."
  git rebase --onto "refs/tags/$TAG" HEAD~1 "$BRANCH"
fi

if [ "$(git rev-list --count "refs/tags/$TAG..HEAD")" != "1" ]; then
  echo "$BRANCH should be exactly one commit on top of $TAG. Squash it first." >&2
  exit 1
fi

echo "Running the grayscale tests..."
./gradlew -q testFullDebugUnitTest --tests "*GrayscaleOwnership*"

git format-patch -1 HEAD --stdout > "$HERE/patches/grayscale.patch"
echo "Updated $HERE/patches/grayscale.patch"
echo
echo "Next:"
echo "  1. git -C \"$CURBOX\" push --force-with-lease origin $BRANCH"
echo "  2. Commit and push patches/grayscale.patch in $HERE"
echo "  3. Run the 'Build patched Curbox' workflow with release $TAG"
