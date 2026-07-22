# waypoint-stack

Pinned, reproducibly-built g4klx digital voice daemons for [Waypoint](https://github.com/KN4OQW/waypoint).

Upstream moved to an MQTT data plane in May 2026 (MMDVM-Host rename, libmosquitto requirement). This repo pins exact upstream commits, builds them for amd64/arm64/armhf in public CI, packages them as .debs, and carries patches only while they are in flight upstream (each patch links its upstream PR).

| Component | Upstream | Pin |
|---|---|---|
| MMDVM-Host | [KN4OQW/MMDVM-Host](https://github.com/KN4OQW/MMDVM-Host) (fork of g4klx) | `fd4a6a4` (g4klx `43edd65` + M17 restored) |
| DMRGateway | [g4klx/DMRGateway](https://github.com/g4klx/DMRGateway) | `79edbc4` (MQTT era) |
| YSFGateway (+ DGIdGateway, YSFParrot) | [g4klx/YSFClients](https://github.com/g4klx/YSFClients) | `2b480aa` (MQTT era) |
| P25Gateway (+ P25Parrot) | [g4klx/P25Clients](https://github.com/g4klx/P25Clients) | `9751c6e` (MQTT era) |
| NXDNGateway (+ NXDNParrot) | [g4klx/NXDNClients](https://github.com/g4klx/NXDNClients) | `18b4e9a` (MQTT era) |
| DAPNETGateway | [g4klx/DAPNETGateway](https://github.com/g4klx/DAPNETGateway) | pending |
| APRSGateway | [g4klx/APRSGateway](https://github.com/g4klx/APRSGateway) | pending |
| DStarGateway | [g4klx/DStarGateway](https://github.com/g4klx/DStarGateway) | `612f388` (MQTT era) |
| M17Gateway | [g4klx/M17Gateway](https://github.com/g4klx/M17Gateway) | `c72b989` (pre-MQTT) |
| MMDVMCal | [g4klx/MMDVMCal](https://github.com/g4klx/MMDVMCal) | pending |

All upstream components GPL-2.0-or-later; build scripts here GPL-3.0.

CI compiles the pinned stack — MMDVM-Host (M17 fork), DMRGateway, YSFGateway/DGIdGateway (+ YSFParrot), P25Gateway (+ P25Parrot), NXDNGateway (+ NXDNParrot), DStarGateway, and M17Gateway — for all three arches and publishes `.deb` artifacts. Still to pin/build: DAPNETGateway (POCSAG), the MMDVM_CM cross-mode bridges, APRSGateway, and MMDVMCal. Tracked in [waypoint#5](https://github.com/KN4OQW/waypoint/issues/5) (MQTT-native status pipeline).

## Supported hardware tiers

| Tier | ISA | Boards |
|---|---|---|
| **armhf** | ARMv7 (hard-float) | Pi Zero 2 W, Pi 2, Pi 3 / 3+, Pi 4 running a 32-bit OS |
| **arm64** | ARMv8-A | Pi 3 / 4 running a 64-bit OS |
| **amd64** | x86-64 | CI and desktop/dev use only |

**Pi Zero W and Pi 1 (ARMv6) are not supported.** Debian armhf targets ARMv7 and faults on ARMv6, and Waypoint no longer builds a Raspbian ARMv6 base. [Pi-Star](https://www.pistar.uk/) remains the recommended option for that hardware.

## Packaging

CI packages the built binaries into Debian `.deb`s with [nfpm](https://nfpm.goreleaser.com/) — one package per daemon, plus a `waypoint-stack` metapackage. Packages ship **binaries and a copyright doc only**: binaries install to `/usr/bin/`, and `waypointd` owns config rendering and systemd unit management, so no config files or units are shipped here. The configs live in [`packaging/`](packaging/).

### Version convention

Daemon packages are versioned `0~git<7-sha>+wp<n>`:

- `<7-sha>` is the upstream commit the binary was built from (the `pins.env` SHA), so the package version names its exact source.
- `+wp<n>` is the Waypoint packaging revision against that same pin. It increments for packaging-only changes (a dependency fix, a doc change) and resets to `wp1` whenever the pin moves.

The `0~git` prefix sorts *below* any future real upstream release version, so a tagged upstream release will always upgrade cleanly over these snapshots.

The `waypoint-stack` metapackage (`arch: all`) carries a single stack version (currently `0.1.0`) and depends on the **exact** versions of every daemon package. Installing it pulls the whole stack at one known-good version set; bump its version whenever any daemon package changes.

### Packages

| Package | Binary (`/usr/bin/`) | Upstream | Pin |
|---|---|---|---|
| `waypoint-mmdvmhost` | `MMDVM-Host` | [KN4OQW/MMDVM-Host](https://github.com/KN4OQW/MMDVM-Host) (fork of g4klx) | `fd4a6a4` |
| `waypoint-dmrgateway` | `DMRGateway` | [g4klx/DMRGateway](https://github.com/g4klx/DMRGateway) | `79edbc4` |
| `waypoint-ysfgateway` | `YSFGateway` | [g4klx/YSFClients](https://github.com/g4klx/YSFClients) | `2b480aa` |
| `waypoint-dgidgateway` | `DGIdGateway` | [g4klx/YSFClients](https://github.com/g4klx/YSFClients) | `2b480aa` |
| `waypoint-ysfparrot` | `YSFParrot` | [g4klx/YSFClients](https://github.com/g4klx/YSFClients) | `2b480aa` |
| `waypoint-p25gateway` | `P25Gateway` | [g4klx/P25Clients](https://github.com/g4klx/P25Clients) | `9751c6e` |
| `waypoint-p25parrot` | `P25Parrot` | [g4klx/P25Clients](https://github.com/g4klx/P25Clients) | `9751c6e` |
| `waypoint-nxdngateway` | `NXDNGateway` | [g4klx/NXDNClients](https://github.com/g4klx/NXDNClients) | `18b4e9a` |
| `waypoint-nxdnparrot` | `NXDNParrot` | [g4klx/NXDNClients](https://github.com/g4klx/NXDNClients) | `18b4e9a` |
| `waypoint-dstargateway` | `dstargateway` | [g4klx/DStarGateway](https://github.com/g4klx/DStarGateway) | `612f388` |
| `waypoint-m17gateway` | `M17Gateway` | [g4klx/M17Gateway](https://github.com/g4klx/M17Gateway) | `c72b989` |
| `waypoint-stack` | *(metapackage, `arch: all`)* | — | pins all of the above at exact versions |

### Dependencies

Runtime dependencies are **measured, not guessed** — `dpkg-shlibdeps` against the built armhf binaries. The MQTT daemons (MMDVM-Host, DMRGateway, the YSF/DG-ID/P25/NXDN gateways, dstargateway) depend on `libc6`, `libgcc-s1`, `libmosquitto1` and `libstdc++6`. `M17Gateway` and the parrots do not link `libmosquitto1` (`M17Gateway` is pre-MQTT; the parrots are local echo). Nothing links a Boost runtime library, so no Boost dependency is declared; `libssl3` is pulled transitively through `libmosquitto1`.

### Building and testing packages locally

```sh
# Fetch the pinned sources (see .github/workflows/build.yml for the exact clone
# steps), then build the binaries for an arch into out/<arch>/:
docker run --rm -v "$PWD:/w" -w /w debian:bookworm bash build.sh out/amd64

# Package every daemon + the metapackage into debs/<arch>/ (needs nfpm on PATH):
packaging/build-debs.sh amd64 out/amd64 debs/amd64

# Install-test the debs in a clean container of the matching arch:
docker run --rm -v "$PWD/debs/amd64:/debs:ro" -v "$PWD/packaging:/packaging:ro" \
  debian:bookworm bash /packaging/install-test.sh
```
Debian armhf targets armv7 and faults on armv6, so the armv6hf job builds its own base image from the official Raspbian archive via `debootstrap` (`armv6-base.sh`), trust-anchored on a pinned archive-key fingerprint — no third-party vendor image, consistent with the no-telemetry stance. Tracked in [waypoint#5](https://github.com/KN4OQW/waypoint/issues/5) (MQTT-native status pipeline).

## systemd

`systemd/waypoint-bus@.service` is the templated unit for an RFC-0003 mode bus (`waypoint-bus@<id>.service`), per [RFC-0003 Addendum A §7](https://github.com/KN4OQW/waypoint/blob/main/docs/rfcs/0003a-loopback-handoff.md). waypointd enables/disables and starts/stops each instance on apply; a DMR bus multiplexes on DMRGateway, a YSF/NXDN bus displaces its gateway (the render + apply enforce the mutual exclusion, so the template needs no per-instance `Conflicts=`).
