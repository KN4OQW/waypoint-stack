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
