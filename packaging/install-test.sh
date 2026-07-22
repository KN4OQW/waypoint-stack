#!/bin/bash
# Install the built .debs into a fresh system and prove the declared dependency
# set is complete: every binary must load and print its version banner with only
# its packaged dependencies present.
#
# Run inside a clean container of the target arch, with the .debs bind-mounted:
#   docker run --rm --platform <plat> -v "$PWD/debs:/debs:ro" \
#     -v "$PWD/packaging:/packaging:ro" debian:bookworm bash /packaging/install-test.sh
#
# DEB_DIR defaults to /debs.
set -euo pipefail
DEB_DIR="${DEB_DIR:-/debs}"
export DEBIAN_FRONTEND=noninteractive

apt-get update -qq

echo "=== dpkg -i (metapackage + daemons), then resolve deps"
# dpkg -i alone fails on unsatisfied deps (e.g. libmosquitto1 is not in the base
# image); apt-get -f install then pulls exactly the declared dependencies. If a
# needed library were NOT declared, it would not be installed here and the probe
# below would fail with "error while loading shared libraries" — which is the
# point of this test.
dpkg -i "$DEB_DIR"/*.deb 2>/dev/null || true
apt-get install -qq -y -f </dev/null >/dev/null

echo "=== installed waypoint packages"
dpkg-query -W -f='  ${Package} ${Version}\n' 'waypoint-*'
# Every waypoint package must be fully configured (status "ii").
bad="$(dpkg-query -W -f='${Package} ${db:Status-Abbrev}\n' 'waypoint-*' | awk '$2 !~ /^ii/{print $1" ("$2")"}')"
if [ -n "$bad" ]; then
  echo "FATAL: some waypoint packages are not fully configured:" >&2
  printf '%s\n' "$bad" >&2
  exit 1
fi

echo "=== version/help probe per binary"
BINS="MMDVM-Host DMRGateway YSFGateway DGIdGateway YSFParrot P25Gateway P25Parrot NXDNGateway NXDNParrot dstargateway M17Gateway"
fail=0
for b in $BINS; do
  path="/usr/bin/$b"
  if [ ! -x "$path" ]; then
    echo "  MISSING: $path"; fail=1; continue
  fi
  out="$("$path" -v 2>&1 || true)"
  [ -n "$(printf '%s' "$out" | tr -d '[:space:]')" ] || out="$("$path" --version 2>&1 || true)"
  if printf '%s' "$out" | grep -q 'error while loading shared libraries'; then
    echo "  DEP FAILURE: $b"; printf '%s\n' "$out" | sed 's/^/    /'; fail=1; continue
  fi
  # first non-empty line is the version banner
  line="$(printf '%s\n' "$out" | grep -m1 . || true)"
  printf '  %-14s %s\n' "$b" "$line"
done
[ "$fail" = 0 ] || { echo "=== INSTALL TEST FAILED" >&2; exit 1; }
echo "=== INSTALL TEST PASSED"
