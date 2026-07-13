#!/bin/bash
# Builds a minimal armv6hf (Pi Zero W / Pi 1) build environment from the
# official Raspbian archive and imports it as a local Docker image.
#
# Why not a prebuilt image: Debian armhf targets armv7 and won't run on
# armv6; the only prebuilt armv6hf Docker userlands are third-party vendor
# images that inject their own entrypoint into the build. Waypoint's
# no-telemetry, self-sufficiency stance means we build our own base from
# the upstream archive, trust-anchored on a pinned archive-key fingerprint.
#
# Needs root (debootstrap) + docker, with armv6 binfmt/qemu registered
# (CI does this via docker/setup-qemu-action). Run:  sudo bash armv6-base.sh
set -euo pipefail

SUITE=bookworm
MIRROR=http://archive.raspbian.org/raspbian
KEY_URL=https://archive.raspbian.org/raspbian.public.key
# Raspbian archive signing key — pinned. debootstrap refuses to proceed if
# the fetched key does not match, so a compromised mirror cannot swap it.
EXPECT_FPR=A0DA38D0D76E8B5D638872819165938D90FDDD2E
IMAGE=waypoint-raspbian-armv6:${SUITE}

export DEBIAN_FRONTEND=noninteractive
if ! command -v debootstrap >/dev/null; then
  apt-get update -qq
  apt-get install -qq -y --no-install-recommends debootstrap wget ca-certificates gnupg >/dev/null
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

echo "=== fetching + verifying Raspbian archive key"
wget -qO "$work/raspbian.key" "$KEY_URL"
got_fpr=$(gpg --show-keys --with-colons "$work/raspbian.key" 2>/dev/null | awk -F: '/^fpr:/{print $10; exit}')
if [ "$got_fpr" != "$EXPECT_FPR" ]; then
  echo "FATAL: Raspbian archive key fingerprint mismatch" >&2
  echo "  expected $EXPECT_FPR" >&2
  echo "  got      $got_fpr" >&2
  exit 1
fi
gpg --dearmor < "$work/raspbian.key" > "$work/raspbian.gpg"

echo "=== debootstrap $SUITE armhf (Raspbian armhf is armv6hf) from $MIRROR"
debootstrap --arch=armhf --variant=minbase \
  --keyring="$work/raspbian.gpg" \
  "$SUITE" "$work/rootfs" "$MIRROR"

echo "=== importing rootfs as $IMAGE"
# --platform is required: without it docker tags the image with the host arch
# (amd64), and a later `docker run --platform linux/arm/v6` would try to pull a
# nonexistent variant instead of running this rootfs under QEMU.
tar -C "$work/rootfs" --numeric-owner -c . \
  | docker import --platform linux/arm/v6 - "$IMAGE" >/dev/null
echo "=== built $IMAGE"
