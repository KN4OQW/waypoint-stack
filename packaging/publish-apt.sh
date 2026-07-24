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
# Env (all optional except the passphrase):
#   APT_SIGNING_PASSPHRASE   required — passphrase for the archive private key,
#                            which must already be imported into the gpg keyring.
#   APT_SIGNING_KEYID        default 41D959A825C3D240 (the Waypoint archive key).
#   WAYPOINT_KEYRING_SHA256  default matches the image's current pin.
#   SUITE / COMPONENT / ORIGIN / LABEL   repo metadata (bookworm / main / …).
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
# Flatten every .deb into the pool; apt-ftparchive reads each deb's own arch. The
# Architecture:all metapackage is built once per arch — identical bytes, one name,
# so it collapses to a single copy here.
find "$DEBS_ROOT" -name '*.deb' -exec cp -f {} "$OUT/$POOL/" \;

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
