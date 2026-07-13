# waypoint-stack

Pinned, reproducibly-built g4klx digital voice daemons for [Waypoint](https://github.com/KN4OQW/waypoint).

Upstream moved to an MQTT data plane in May 2026 (MMDVM-Host rename, libmosquitto requirement). This repo pins exact upstream commits, builds them for armv6/armhf/arm64 in public CI, packages them as .debs, and carries patches only while they are in flight upstream (each patch links its upstream PR).

| Component | Upstream | Pin |
|---|---|---|
| MMDVM-Host | [g4klx/MMDVM-Host](https://github.com/g4klx/MMDVM-Host) | _Phase 0: pending first pin_ |
| DMRGateway | [g4klx/DMRGateway](https://github.com/g4klx/DMRGateway) | pending |
| YSFGateway (+ YSFParrot) | [g4klx/YSFClients](https://github.com/g4klx/YSFClients) | `2b480aa` (MQTT era) |
| P25Gateway | [g4klx/P25Clients](https://github.com/g4klx/P25Clients) | pending |
| NXDNGateway | [g4klx/NXDNClients](https://github.com/g4klx/NXDNClients) | pending |
| DAPNETGateway | [g4klx/DAPNETGateway](https://github.com/g4klx/DAPNETGateway) | pending |
| APRSGateway | [g4klx/APRSGateway](https://github.com/g4klx/APRSGateway) | pending |
| DStarGateway | [g4klx/DStarGateway](https://github.com/g4klx/DStarGateway) | pending |
| MMDVMCal | [g4klx/MMDVMCal](https://github.com/g4klx/MMDVMCal) | pending |

All upstream components GPL-2.0-or-later; build scripts here GPL-3.0.

First milestone: CI compiles MMDVM-Host (MQTT era) + DMRGateway for all four arches (amd64, arm64, armhf/armv7, armv6hf) and publishes artifacts. The amd64/arm64/armhf builds run on every push/PR (`build.yml`); armv6hf (Pi Zero W / Pi 1) has its own gated workflow (`build-armv6.yml`) that runs only when a build input changes or on manual dispatch, because it builds under slow QEMU emulation.

Debian armhf targets armv7 and faults on armv6, so the armv6hf job builds its own base image from the official Raspbian archive via `debootstrap` (`armv6-base.sh`), trust-anchored on a pinned archive-key fingerprint — no third-party vendor image, consistent with the no-telemetry stance. Tracked in [waypoint#5](https://github.com/KN4OQW/waypoint/issues/5) (MQTT-native status pipeline).
