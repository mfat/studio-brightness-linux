#!/usr/bin/env bash
# Write a new version and changelog into every file that carries them: the
# studio-brightness script, the RPM spec, the AppStream metainfo, the man page and
# debian/changelog. The Arch PKGBUILD follows after the tag exists
# (scripts/update-arch-pkgbuild.sh), since its checksum covers the tag's tarball.
#
#   scripts/bump-version.sh <version> < changelog.txt
#   scripts/bump-version.sh --check <version>     # validate only, print the current version
#
# Only edits files, so the Release workflow and a local release share these rules.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

SCRIPT=studio-brightness
SPEC=packaging/fedora/studio-brightness-linux.spec
METAINFO=data/io.github.mfat.StudioBrightness.metainfo.xml
MANPAGE=data/studio-brightness.1
DEB_CHANGELOG=debian/changelog

CHECK_ONLY=0
if [[ ${1:-} == --check ]]; then
  CHECK_ONLY=1
  shift
fi

VERSION=${1:-}
VERSION=${VERSION#v}
if [[ ! $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Usage: $0 [--check] X.Y.Z < changelog" >&2
  exit 1
fi

CURRENT=$(sed -nE 's/^__version__ = "([^"]+)"/\1/p' "$SCRIPT")
if [[ -z $CURRENT ]]; then
  echo "ERROR: no __version__ in $SCRIPT" >&2
  exit 1
fi
if [[ $(printf '%s\n%s\n' "$CURRENT" "$VERSION" | sort -V | tail -1) != "$VERSION" || $CURRENT == "$VERSION" ]]; then
  echo "ERROR: new version $VERSION must be greater than current $CURRENT" >&2
  exit 1
fi

if (( CHECK_ONLY )); then
  echo "$CURRENT"
  exit 0
fi

command -v dch >/dev/null || { echo "ERROR: dch is required (apt install devscripts)" >&2; exit 1; }

# One change per line; leading "-" or "*" bullets are dropped.
mapfile -t CHANGES < <(sed -E 's/^[[:space:]]*[-*]?[[:space:]]*//; /^$/d')
if (( ${#CHANGES[@]} == 0 )); then
  echo "ERROR: empty changelog" >&2
  exit 1
fi

sed -i -E "s/^__version__ = \"[^\"]+\"/__version__ = \"$VERSION\"/" "$SCRIPT"
sed -i -E "s/^(Version:\s+%\{\?version\}%\{!\?version:)[^}]+\}/\1$VERSION}/" "$SPEC"
sed -i -E "1s/\"[^\"]*\" \"studio-brightness [^\"]*\"/\"$(LC_ALL=C date '+%B %Y')\" \"studio-brightness $VERSION\"/" "$MANPAGE"

python3 - "$SPEC" "$METAINFO" "$VERSION" "${CHANGES[@]}" <<'PY'
import html
import re
import sys
from datetime import date
from pathlib import Path

spec, metainfo, version, *changes = sys.argv[1:]
today = date.today()

path = Path(spec)
entry = (f"* {today:%a %b %d %Y} Mehdi <mah.fat@gmail.com> - {version}-1\n"
         + "".join(f"- {c}\n" for c in changes) + "\n")
text, n = re.subn(r"(%changelog\n)", lambda m: m.group(1) + entry, path.read_text(), count=1)
if not n:
    raise SystemExit(f"ERROR: no %changelog in {spec}")
path.write_text(text)

path = Path(metainfo)
paras = "".join(f"        <p>{html.escape(c)}</p>\n" for c in changes)
release = (f'    <release version="{version}" date="{today:%Y-%m-%d}">\n'
           f"      <description>\n{paras}      </description>\n    </release>\n")
text, n = re.subn(r"(<releases>\n)", lambda m: m.group(1) + release, path.read_text(), count=1)
if not n:
    raise SystemExit(f"ERROR: no <releases> in {metainfo}")
path.write_text(text)
PY

export DEBFULLNAME=${DEBFULLNAME:-Mehdi} DEBEMAIL=${DEBEMAIL:-mah.fat@gmail.com}
dch -c "$DEB_CHANGELOG" -v "$VERSION-1" -D unstable --force-distribution "Release v$VERSION."
for change in "${CHANGES[@]}"; do
  dch -c "$DEB_CHANGELOG" -a "$change"
done

echo "Bumped $CURRENT -> $VERSION"
