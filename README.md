# waypoint-stack

Pinned, reproducibly-built g4klx digital voice daemons for [Waypoint](https://github.com/KN4OQW/waypoint).

Upstream moved to an MQTT data plane in May 2026 (MMDVM-Host rename, libmosquitto requirement). This repo pins exact upstream commits, builds them for amd64/arm64/armhf/armv6 in public CI, packages them as .debs, and carries patches only while they are in flight upstream (each patch links its upstream PR).

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

CI compiles the pinned stack — MMDVM-Host (M17 fork), DMRGateway, YSFGateway/DGIdGateway (+ YSFParrot), P25Gateway (+ P25Parrot), NXDNGateway (+ NXDNParrot), DStarGateway, and M17Gateway — for all four arches (amd64, arm64, armhf/armv7, armv6hf) and publishes artifacts. Still to pin/build: DAPNETGateway (POCSAG), the MMDVM_CM cross-mode bridges, APRSGateway, and MMDVMCal. The amd64/arm64/armhf builds run on every push/PR (`build.yml`); armv6hf (Pi Zero W / Pi 1) has its own gated workflow (`build-armv6.yml`) that runs only when a build input changes or on manual dispatch, because it builds under slow QEMU emulation.

Debian armhf targets armv7 and faults on armv6, so the armv6hf job builds its own base image from the official Raspbian archive via `debootstrap` (`armv6-base.sh`), trust-anchored on a pinned archive-key fingerprint — no third-party vendor image, consistent with the no-telemetry stance. Tracked in [waypoint#5](https://github.com/KN4OQW/waypoint/issues/5) (MQTT-native status pipeline).

## systemd

`systemd/waypoint-bus@.service` is the templated unit for an RFC-0003 mode bus (`waypoint-bus@<id>.service`), per [RFC-0003 Addendum A §7](https://github.com/KN4OQW/waypoint/blob/main/docs/rfcs/0003a-loopback-handoff.md). waypointd enables/disables and starts/stops each instance on apply; a DMR bus multiplexes on DMRGateway, a YSF/NXDN bus displaces its gateway (the render + apply enforce the mutual exclusion, so the template needs no per-instance `Conflicts=`).
