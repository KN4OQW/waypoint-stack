#!/usr/bin/env bash
# Assemble a signed apt repository from the built .debs, laid out as a static tree
# ready to serve from GitHub Pages.
#
# The repo is consumed as a deb822 source by the Waypoint image
# (KN4OQW/waypoint image module): suite=bookworm, component=main, Signed-By the
# Waypoint archive keyring. The image pins that keyring by sha256, so this script
# exports the public keyring and FAILS LOUDLY if it drifts from the pin — a repo
# signed by a different key (or exported to different bytes) would make every
# freshly built image reject this repo.
#
#   usage: publish-apt.sh <debs-root> <out-dir>
#     <debs-root>  a directory tree containing the built *.deb files (any depth;
#                  arch is read from each package, not the path).
#     <out-dir>    the repository tree is (re)created here.
#
# THE POOL RETAINS PREVIOUS VERSIONS. This script used to build the tree from only
# the current build's .debs, so the published repo carried exactly one version of
# each package. That silently broke rollback on every node: waypointd's stack
# updater reverts a failed update with `apt-get install <previous versions>`, and
# those versions were not there —
#
#   stackupdate: REVERT FAILED (…): E: Version '0.1.0' for 'waypoint-stack' was not found
#
# stranding the node on the new version (KN4OQW/waypoint#221). The pool now keeps
# KEEP_VERSIONS versions of each package per architecture, so a node always has
# somewhere to go back to.
#
# Because GitHub Pages deploys from a workflow artifact rather than a branch, the
# previously published .debs exist in exactly one place: the live site. So this
# fetches the current pool from BASE_URL and merges the new build over it. That
# fetch is load-bearing — if it fails, the "retention" would silently be one
# version again, which is the bug — so a fetch failure is fatal unless the repo is
# genuinely being published for the first time (ALLOW_EMPTY_POOL=1).
#
# Env (all optional except the passphrase):
#   APT_SIGNING_PASSPHRASE   required — passphrase for the archive private key,
#                            which must already be imported into the gpg keyring.
#   APT_SIGNING_KEYID        default 41D959A825C3D240 (the Waypoint archive key).
#   WAYPOINT_KEYRING_SHA256  default matches the image's current pin.
#   SUITE / COMPONENT / ORIGIN / LABEL   repo metadata (bookworm / main / …).
#   KEEP_VERSIONS            versions retained per package per arch (default 4 —
#                            the current one plus three previous).
#   BASE_URL                 the live repo to inherit the pool from.
#   ALLOW_EMPTY_POOL=1       permit publishing with no inherited pool (bootstrap
#                            only; it is what makes rollback impossible).
set -euo pipefail

DEBS_ROOT="${1:?usage: publish-apt.sh <debs-root> <out-dir>}"
OUT="${2:?usage: publish-apt.sh <debs-root> <out-dir>}"

SUITE="${SUITE:-bookworm}"
COMPONENT="${COMPONENT:-main}"
ORIGIN="${ORIGIN:-Waypoint}"
LABEL="${LABEL:-Waypoint stack}"
KEYID="${APT_SIGNING_KEYID:-41D959A825C3D240}"
# The archive keyring sha256 the image pins
# (image/src/modules/waypoint/config in KN4OQW/waypoint). Publishing a repo whose
# exported keyring differs would silently break image builds.
KEYRING_SHA256="${WAYPOINT_KEYRING_SHA256:-aa4641f449f5ca7364079e41b66ecd74175855d21c1fd7e414451b87a4f67ec2}"
# 4 = the version being published plus three previous. Three covers a node that
# sat out a couple of updates and still needs a way back; the cost is trivial
# (a full version set of every package is ~3 MiB across both arches).
KEEP_VERSIONS="${KEEP_VERSIONS:-4}"
BASE_URL="${BASE_URL:-https://kn4oqw.github.io/waypoint-stack}"

: "${APT_SIGNING_PASSPHRASE:?set APT_SIGNING_PASSPHRASE (archive key passphrase)}"

# Architectures = every non-'all' arch present among the debs (read from the
# packages themselves, so the input layout does not matter).
mapfile -t ARCHES < <(
  find "$DEBS_ROOT" -name '*.deb' -exec dpkg-deb -f {} Architecture \; | sort -u | grep -v '^all$'
)
[ "${#ARCHES[@]}" -gt 0 ] || { echo "no arch-specific .debs found under $DEBS_ROOT" >&2; exit 1; }
echo "publishing suite=$SUITE component=$COMPONENT arches=${ARCHES[*]}"

rm -rf "$OUT"
POOL="pool/$COMPONENT"
mkdir -p "$OUT/$POOL"

# --- inherit the currently published pool -----------------------------------
#
# Read the live Packages indices to learn which .debs the published repo holds,
# then fetch each one. Going through the indices rather than guessing filenames
# means this follows whatever is actually published, and it doubles as the check
# that the repo is reachable and well-formed.
inherited=0
fetch_failed=0
for a in "${ARCHES[@]}"; do
  idx="$(curl -fsSL "$BASE_URL/dists/$SUITE/$COMPONENT/binary-$a/Packages" 2>/dev/null)" || {
    echo "note: no published Packages index for $a at $BASE_URL" >&2
    fetch_failed=1
    continue
  }
  # Filename: lines are pool-relative paths, e.g. pool/main/waypoint-foo_1.2_armhf.deb
  while read -r rel; do
    [ -n "$rel" ] || continue
    dest="$OUT/$POOL/$(basename "$rel")"
    [ -e "$dest" ] && continue        # already inherited via another arch's index
    if curl -fsSL -o "$dest" "$BASE_URL/$rel"; then
      inherited=$((inherited + 1))
    else
      echo "ERROR: $BASE_URL/$rel is indexed but could not be downloaded" >&2
      rm -f "$dest"
      fetch_failed=1
    fi
  done < <(printf '%s\n' "$idx" | awk '/^Filename:/{print $2}')
done

# A failed inherit must not quietly degrade into "one version in the pool" — that
# is precisely the bug this retention exists to fix, and it would look like a
# successful publish. Fail loudly instead, and require an explicit opt-out for the
# genuine first publish.
if [ "$fetch_failed" -ne 0 ] && [ "${ALLOW_EMPTY_POOL:-0}" != "1" ]; then
  echo "::error::could not inherit the published pool from $BASE_URL. Publishing now" >&2
  echo "  would drop every previous version and leave nodes unable to roll back" >&2
  echo "  (KN4OQW/waypoint#221). Fix the fetch, or set ALLOW_EMPTY_POOL=1 if this" >&2
  echo "  really is the first publish of a new repository." >&2
  exit 1
fi
echo "inherited $inherited .deb(s) from the published pool"

# Flatten every .deb into the pool; apt-ftparchive reads each deb's own arch. The
# Architecture:all metapackage is built once per arch — identical bytes, one name,
# so it collapses to a single copy here. This overwrites an inherited file of the
# same name, so a rebuild of an already-published version wins.
find "$DEBS_ROOT" -name '*.deb' -exec cp -f {} "$OUT/$POOL/" \;

# --- prune to KEEP_VERSIONS per package per arch -----------------------------
#
# Ordering is decided by `dpkg --compare-versions`, not by sorting the filenames:
# the two disagree, which is the whole reason the version scheme carries a date
# (see README.md, "Version convention"). Package name, version and arch are read
# from each .deb's own control data, so a filename says nothing here either.
prune_pool() {
  local dir="$1" keep="$2"
  local f name ver arch key
  local -A groups=()
  for f in "$dir"/*.deb; do
    [ -e "$f" ] || continue
    name="$(dpkg-deb -f "$f" Package)"
    ver="$(dpkg-deb -f "$f" Version)"
    arch="$(dpkg-deb -f "$f" Architecture)"
    key="$name/$arch"
    groups["$key"]+="$ver	$f"$'\n'
  done

  for key in "${!groups[@]}"; do
    # Insertion-sort this group's versions newest-first using dpkg's own ordering.
    local -a vers=() files=()
    while IFS=$'\t' read -r ver f; do
      [ -n "$ver" ] || continue
      local i=${#vers[@]}
      vers+=("$ver"); files+=("$f")
      while [ "$i" -gt 0 ] && dpkg --compare-versions "${vers[i-1]}" lt "$ver"; do
        vers[i]="${vers[i-1]}"; files[i]="${files[i-1]}"
        vers[i-1]="$ver";       files[i-1]="$f"
        i=$((i-1))
      done
    done <<< "${groups[$key]}"

    local n=${#vers[@]}
    [ "$n" -le "$keep" ] && continue
    echo "  $key: keeping $keep of $n"
    local j
    for ((j = keep; j < n; j++)); do
      echo "    prune ${vers[$j]}"
      rm -f "${files[$j]}"
    done
  done
}
echo "pruning the pool to $KEEP_VERSIONS version(s) per package per arch"
prune_pool "$OUT/$POOL" "$KEEP_VERSIONS"

cd "$OUT"

# Per-arch Packages indices (apt-ftparchive --arch keeps that arch plus 'all').
for a in "${ARCHES[@]}"; do
  d="dists/$SUITE/$COMPONENT/binary-$a"
  mkdir -p "$d"
  apt-ftparchive --arch "$a" packages "$POOL" > "$d/Packages"
  gzip -9c "$d/Packages" > "$d/Packages.gz"
done

# Suite Release over the dists tree (hashes every Packages index).
arch_list="${ARCHES[*]}"
apt-ftparchive \
  -o "APT::FTPArchive::Release::Origin=$ORIGIN" \
  -o "APT::FTPArchive::Release::Label=$LABEL" \
  -o "APT::FTPArchive::Release::Suite=$SUITE" \
  -o "APT::FTPArchive::Release::Codename=$SUITE" \
  -o "APT::FTPArchive::Release::Components=$COMPONENT" \
  -o "APT::FTPArchive::Release::Architectures=$arch_list" \
  release "dists/$SUITE" > "dists/$SUITE/Release.tmp"
# apt-ftparchive does not emit Date; apt treats a Release with no Date as always
# stale, so prepend one.
{ printf 'Date: %s\n' "$(date -Ru)"; cat "dists/$SUITE/Release.tmp"; } > "dists/$SUITE/Release"
rm -f "dists/$SUITE/Release.tmp"

# Sign: detached (Release.gpg) + inline (InRelease). Loopback so the passphrase
# comes from the env, never a tty.
gpg_sign() {
  gpg --batch --yes --pinentry-mode loopback \
    --passphrase "$APT_SIGNING_PASSPHRASE" --local-user "$KEYID" "$@"
}
gpg_sign --detach-sign --armor -o "dists/$SUITE/Release.gpg" "dists/$SUITE/Release"
gpg_sign --clearsign           -o "dists/$SUITE/InRelease"   "dists/$SUITE/Release"

# Public keyring at the repo root — must byte-match the image's pin, or newly
# built images will refuse this repo.
gpg --batch --export "$KEYID" > waypoint-archive-keyring.gpg
echo "${KEYRING_SHA256}  waypoint-archive-keyring.gpg" | sha256sum -c -

echo "== apt repository assembled at $OUT =="
find . -maxdepth 4 -type f | sort
