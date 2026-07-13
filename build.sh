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
  g++ make git ca-certificates libmosquitto-dev nlohmann-json3-dev libboost-dev >/dev/null

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
# P25Clients likewise: the P25 gateway and the local parrot (echo).
build_component P25Clients  src/P25Clients  P25Gateway/P25Gateway P25Parrot/P25Parrot
# NXDNClients likewise: the NXDN gateway and the local parrot (echo).
build_component NXDNClients src/NXDNClients NXDNGateway/NXDNGateway NXDNParrot/NXDNParrot
# M17Gateway's Makefile 'all' builds just the gateway (echo/parrot is built in).
# Pre-MQTT: no libmosquitto, no [MQTT] section — links against libpthread only.
build_component M17Gateway  src/M17Gateway  M17Gateway
# DStarGateway's top Makefile 'all' also builds the DGW* helper tools (text/voice
# transmit, time server) we don't ship; build just the gateway target to keep it
# lean and avoid depending on tools outside our scope. The binary is lowercase
# dstargateway under its own subdir.
echo "=== building DStarGateway"
make -C src/DStarGateway DStarGateway/dstargateway -j"$(nproc)"
strip src/DStarGateway/DStarGateway/dstargateway
cp src/DStarGateway/DStarGateway/dstargateway "$OUT/"

echo "=== artifacts"
ls -la "$OUT"
