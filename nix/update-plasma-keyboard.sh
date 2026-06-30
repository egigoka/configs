#!/usr/bin/env bash
# Update the egigoka/plasma-keyboard fork pin and rebuild via home-manager.
#
# What it does:
#   1. Resolves the target commit on the fork (default: latest origin/master).
#   2. Prefetches the fetchFromGitHub SRI hash for that commit.
#   3. Reads PROJECT_VERSION from the commit's CMakeLists.txt for the version base.
#   4. Bumps the ".eN" suffix in plasma-keyboard.nix. The suffix changes the
#      installed org.kde.plasma.keyboard.<version>.desktop filename on every run;
#      KWin caches the resolved input-method binary by that path, so a new path is
#      what forces it to pick up the rebuilt binary (the HM activation hook then
#      rewrites kwinrc [Wayland] InputMethod to the new file).
#   5. Rewrites rev/hash/version in plasma-keyboard.nix.
#   6. Runs home-manager switch (unless --bump-only).
#
# Usage:
#   update-plasma-keyboard.sh [REV|BRANCH]   # default: master
#   update-plasma-keyboard.sh --bump-only    # edit the nix pin, skip the switch
#   update-plasma-keyboard.sh -h
#
# Note: KWin only reads [Wayland] InputMethod at compositor start, so a Plasma/
# KWin restart (or relogin) is still required for the new binary to actually load.
set -euo pipefail

OWNER=egigoka
REPO=plasma-keyboard
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIX_FILE="$SCRIPT_DIR/plasma-keyboard.nix"
CONFIGS_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

REF=master
BUMP_ONLY=0
for arg in "$@"; do
  case "$arg" in
    -h|--help) sed -n '2,24p' "$0" | sed 's/^# \?//'; exit 0 ;;
    --bump-only) BUMP_ONLY=1 ;;
    *) REF="$arg" ;;
  esac
done

die() { echo "error: $*" >&2; exit 1; }
[ -f "$NIX_FILE" ] || die "cannot find $NIX_FILE"

echo ">> resolving $OWNER/$REPO @ $REF ..."
# Accept a literal 40-char sha, otherwise resolve the ref on the remote.
if [[ "$REF" =~ ^[0-9a-f]{40}$ ]]; then
  REV="$REF"
else
  REV="$(git ls-remote "https://github.com/$OWNER/$REPO.git" "$REF" | cut -f1 | head -1)"
fi
[ -n "${REV:-}" ] || die "could not resolve ref '$REF'"
SHORT="${REV:0:7}"
echo "   rev = $REV"

echo ">> prefetching source hash ..."
HASH="$(nix run --impure nixpkgs#nix-prefetch-github -- "$OWNER" "$REPO" --rev "$REV" 2>/dev/null \
  | grep -oE 'sha256-[A-Za-z0-9+/=]{40,}' | head -1)"
[ -n "${HASH:-}" ] || die "nix-prefetch-github did not return a hash"
echo "   hash = $HASH"

echo ">> determining version base ..."
BASE="$(curl -fsSL "https://raw.githubusercontent.com/$OWNER/$REPO/$REV/CMakeLists.txt" 2>/dev/null \
  | grep -oP 'set\(PROJECT_VERSION "\K[^"]+' | head -1 || true)"
CUR_VERSION="$(grep -oP 'version = "\K[^"]+' "$NIX_FILE" | head -1)"
[ -n "${BASE:-}" ] || BASE="$(echo "$CUR_VERSION" | grep -oP '^[0-9][0-9.]*(?=-)')"
# Increment the .eN suffix (default to e1 if none present).
N="$(echo "$CUR_VERSION" | grep -oP '\.e\K[0-9]+$' || echo 0)"
N=$((N + 1))
NEW_VERSION="${BASE}-unstable-${SHORT}.e${N}"
echo "   version = $CUR_VERSION -> $NEW_VERSION"

echo ">> editing $NIX_FILE ..."
sed -i \
  -e "s|rev = \"[0-9a-f]*\";|rev = \"$REV\";|" \
  -e "s|hash = \"sha256-[^\"]*\";|hash = \"$HASH\";|" \
  -e "s|version = \"[^\"]*\";|version = \"$NEW_VERSION\";|" \
  "$NIX_FILE"

# Verify the edits landed.
grep -q "rev = \"$REV\";" "$NIX_FILE"         || die "rev not updated"
grep -q "hash = \"$HASH\";" "$NIX_FILE"       || die "hash not updated"
grep -q "version = \"$NEW_VERSION\";" "$NIX_FILE" || die "version not updated"
git -C "$CONFIGS_DIR" --no-pager diff -- "$NIX_FILE" || true

if [ "$BUMP_ONLY" -eq 1 ]; then
  echo ">> --bump-only: skipping home-manager switch."
  exit 0
fi

echo ">> running home-manager switch ..."
nix run --refresh --impure home-manager/release-26.05 -- switch --impure -b backup \
  --flake "$CONFIGS_DIR/nix#default"

cat <<EOF

>> done. plasma-keyboard updated to $SHORT (version $NEW_VERSION).
   KWin reads [Wayland] InputMethod only at compositor start, so restart
   Plasma/KWin (or relogin) for the new binary to load.
EOF
