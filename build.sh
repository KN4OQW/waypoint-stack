#!/bin/bash
# Builds the pinned stack components inside a Debian container for the
# container's native architecture. Invoked by CI via docker run, or directly
# on any Debian-family host:  ./build.sh /path/to/output
set -euo pipefail

OUT="${1:-out}"
mkdir -p "$OUT"

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -qq -y --no-install-recommends \
  g++ make git ca-certificates libmosquitto-dev nlohmann-json3-dev >/dev/null

build_component() { # name, srcdir, binaries...
  local name="$1" src="$2"; shift 2
  echo "=== building $name"
  make -C "$src" -j"$(nproc)"
  for bin in "$@"; do
    strip "$src/$bin"
    cp "$src/$bin" "$OUT/"
  done
}

build_component MMDVM-Host  src/MMDVM-Host  MMDVM-Host
build_component DMRGateway  src/DMRGateway  DMRGateway
# YSFClients' top Makefile builds each sub-daemon in its own directory; we ship
# the System Fusion gateway and the local parrot (echo) for bench testing.
build_component YSFClients  src/YSFClients  YSFGateway/YSFGateway YSFParrot/YSFParrot

echo "=== artifacts"
ls -la "$OUT"
