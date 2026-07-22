#!/bin/bash
# Publish the waypoint-stack .debs as a signed, static apt repository.
#
#   scripts/publish-apt.sh --debs <dir> --output <dir> [options]
#
# Runs aptly (repo add -> snapshot -> publish) against a throwaway aptly root and
# emits a GPG-signed publish tree (dists/ + pool/) into --output, ready to serve
# from GitHub Pages.
#
# STATE / ROLLBACK MODEL
#   aptly's own database is NOT persisted between runs. Instead, state is
#   reconstructed from the previously published tree: every .deb already in
#   <previous>/pool/ is re-added before the new .debs, so pool/ accumulates all
#   versions ever published. An aptly repo happily holds multiple versions of the
#   same package, so the published Packages indices list them all and apt can
#   install or downgrade to any prior version (apt-get install pkg=<version>).
#   The published tree is therefore the single source of truth; losing the aptly
#   db costs nothing.
#
# OPTIONS
#   --debs <dir>         directory of .debs to add this run (required)
#   --output <dir>       directory to write the publish tree into (required)
#   --previous <dir>     previously published tree to carry versions forward from
#                        (its pool/ is re-added). Omit for the first publish.
#   --gpg-key <id>       signing key id / fingerprint / email (required)
#   --passphrase-file <f> file containing the signing key passphrase (required)
#   --dist <name>        distribution codename (default: bookworm)
#   --component <name>   component (default: main)
#   --arches <csv>       architectures (default: armhf,arm64,amd64)
#
# GNUPGHOME must point at a keyring holding the secret key (the CI workflow
# imports APT_SIGNING_KEY into a throwaway GNUPGHOME before calling this).
set -euo pipefail

DEBS_DIR="" OUTPUT_DIR="" PREVIOUS_DIR="" GPG_KEY="" PASSFILE=""
DIST="bookworm" COMPONENT="main" ARCHES="armhf,arm64,amd64"
while [ $# -gt 0 ]; do
  case "$1" in
    --debs)            DEBS_DIR="$2"; shift 2 ;;
    --output)          OUTPUT_DIR="$2"; shift 2 ;;
    --previous)        PREVIOUS_DIR="$2"; shift 2 ;;
    --gpg-key)         GPG_KEY="$2"; shift 2 ;;
    --passphrase-file) PASSFILE="$2"; shift 2 ;;
    --dist)            DIST="$2"; shift 2 ;;
    --component)       COMPONENT="$2"; shift 2 ;;
    --arches)          ARCHES="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

die() { echo "FATAL: $*" >&2; exit 1; }
[ -n "$DEBS_DIR" ]   || die "--debs is required"
[ -n "$OUTPUT_DIR" ] || die "--output is required"
[ -n "$GPG_KEY" ]    || die "--gpg-key is required"
[ -n "$PASSFILE" ]   || die "--passphrase-file is required"
[ -d "$DEBS_DIR" ]   || die "--debs dir '$DEBS_DIR' does not exist"
[ -f "$PASSFILE" ]   || die "--passphrase-file '$PASSFILE' does not exist"
command -v aptly >/dev/null || die "aptly not found on PATH"
ls "$DEBS_DIR"/*.deb >/dev/null 2>&1 || die "no .debs in '$DEBS_DIR'"

REPO="waypoint"
# JSON array form of the arches for aptly.conf, e.g. "armhf","arm64","amd64"
ARCH_JSON=$(printf '%s' "$ARCHES" | awk -F, '{for(i=1;i<=NF;i++){printf "%s\"%s\"",(i>1?",":""),$i}}')

APTLY_ROOT="$(mktemp -d)"
trap 'rm -rf "$APTLY_ROOT"' EXIT
CONF="$APTLY_ROOT/aptly.conf"
cat > "$CONF" <<EOF
{
  "rootDir": "$APTLY_ROOT/db",
  "architectures": [$ARCH_JSON],
  "gpgProvider": "gpg"
}
EOF
aptly() { command aptly -config="$CONF" "$@"; }

echo "=== creating aptly repo '$REPO' ($DIST/$COMPONENT, arches: $ARCHES)"
aptly repo create -distribution="$DIST" -component="$COMPONENT" "$REPO" >/dev/null

# Reconstruct prior state: carry every previously published .deb forward so pool/
# retains all versions (the downgrade story).
if [ -n "$PREVIOUS_DIR" ] && [ -d "$PREVIOUS_DIR/pool" ]; then
  mapfile -d '' prior < <(find "$PREVIOUS_DIR/pool" -name '*.deb' -print0)
  echo "=== carrying forward ${#prior[@]} package file(s) from previous pool/"
  if [ "${#prior[@]}" -gt 0 ]; then
    # one aptly invocation (aptly repo add accepts many files); adding an already
    # present version is a harmless no-op, so re-publishing is idempotent.
    aptly repo add "$REPO" "${prior[@]}"
  fi
else
  echo "=== no previous tree provided; publishing fresh"
fi

echo "=== adding $(ls "$DEBS_DIR"/*.deb | wc -l) new .deb(s)"
aptly repo add "$REPO" "$DEBS_DIR"

echo "=== repo now contains:"
aptly repo show -with-packages "$REPO" | sed 's/^/  /'

SNAP="${REPO}-$(date -u +%Y%m%dT%H%M%SZ)-$$"
aptly snapshot create "$SNAP" from repo "$REPO" >/dev/null

echo "=== publishing + signing snapshot $SNAP with key $GPG_KEY"
aptly publish snapshot \
  -architectures="$ARCHES" \
  -distribution="$DIST" -component="$COMPONENT" \
  -origin="Waypoint" -label="Waypoint Stack" \
  -gpg-key="$GPG_KEY" -passphrase-file="$PASSFILE" -batch \
  "$SNAP" >/dev/null

# aptly writes the published tree to <rootDir>/public/
PUBLIC="$APTLY_ROOT/db/public"
[ -d "$PUBLIC/dists" ] || die "publish produced no dists/ (signing likely failed)"

mkdir -p "$OUTPUT_DIR"
cp -a "$PUBLIC/." "$OUTPUT_DIR/"

echo "=== publish tree written to $OUTPUT_DIR"
echo "  dists:  $(find "$OUTPUT_DIR/dists" -maxdepth 3 -name 'Release' -o -name 'InRelease' | sed "s#$OUTPUT_DIR/##" | tr '\n' ' ')"
echo "  pool:   $(find "$OUTPUT_DIR/pool" -name '*.deb' | wc -l) package file(s)"
