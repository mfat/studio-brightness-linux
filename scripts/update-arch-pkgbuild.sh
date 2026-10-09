#!/usr/bin/env bash
# Point packaging/ArchLinux/PKGBUILD at a released tag.
#
#   scripts/update-arch-pkgbuild.sh <version>
#
# Must run after the tag is pushed: sha256sums covers the tarball GitHub generates
# for the tag. Edits the file only; the caller commits.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

PKGBUILD=packaging/ArchLinux/PKGBUILD
VERSION=${1:?Usage: $0 <version>}
VERSION=${VERSION#v}
URL="https://github.com/mfat/studio-brightness-linux/archive/refs/tags/v${VERSION}.tar.gz"

TARBALL=$(mktemp)
trap 'rm -f "$TARBALL"' EXIT

SHA=
for attempt in 1 2 3 4 5; do
  # GitHub generates the tarball on first request; give it a moment.
  if curl -sfL -o "$TARBALL" "$URL"; then
    SHA=$(sha256sum "$TARBALL" | cut -d' ' -f1)
    break
  fi
  echo "tarball not ready yet (attempt $attempt), retrying..."
  sleep 5
done
if [[ -z $SHA ]]; then
  echo "ERROR: could not download $URL" >&2
  exit 1
fi

sed -i -e "s/^pkgver=.*/pkgver=${VERSION}/" \
       -e "s/^pkgrel=.*/pkgrel=1/" \
       -e "s/^sha256sums=.*/sha256sums=('${SHA}')/" "$PKGBUILD"
echo "pkgver=$VERSION sha256sums=($SHA)"
