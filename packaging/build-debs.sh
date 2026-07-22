#!/bin/bash
# Package the built stack into .debs with nfpm.
#
#   packaging/build-debs.sh <pkg_arch> <bin_dir> <out_dir>
#
#   pkg_arch   nfpm/deb architecture: amd64 | arm64 | armhf
#   bin_dir    directory holding the built binaries (e.g. out/armhf)
#   out_dir    directory to write the .debs into (created if absent)
#
# nfpm does not expand environment variables in a content's `src:` glob, so we
# stage the arch's binaries at a fixed path (packaging/staging/) that every
# nfpm.yaml references literally. The architecture, by contrast, IS expanded in
# scalar fields, so it is passed through PKG_ARCH.
set -euo pipefail

PKG_ARCH="${1:?usage: build-debs.sh <pkg_arch> <bin_dir> <out_dir>}"
BIN_DIR="${2:?usage: build-debs.sh <pkg_arch> <bin_dir> <out_dir>}"
OUT_DIR="${3:?usage: build-debs.sh <pkg_arch> <bin_dir> <out_dir>}"

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

[ -d "$BIN_DIR" ] || { echo "FATAL: bin_dir '$BIN_DIR' does not exist" >&2; exit 1; }
mkdir -p "$OUT_DIR"

# Stage the built binaries where the nfpm configs expect them.
rm -rf packaging/staging
mkdir -p packaging/staging
cp "$BIN_DIR"/* packaging/staging/
trap 'rm -rf packaging/staging' EXIT

export PKG_ARCH
# Package each daemon, then the metapackage last (its src is only the copyright).
for cfg in packaging/*.nfpm.yaml; do
  echo "=== nfpm: $(basename "$cfg") (arch=$PKG_ARCH)"
  nfpm package -f "$cfg" -p deb -t "$OUT_DIR"
done

echo "=== built .debs"
ls -la "$OUT_DIR"
