# waypoint-stack

Pinned, reproducibly-built g4klx digital voice daemons for [Waypoint](https://github.com/KN4OQW/waypoint).

Upstream moved to an MQTT data plane in May 2026 (MMDVM-Host rename, libmosquitto requirement). This repo pins exact upstream commits, builds them for armv6/armhf/arm64 in public CI, packages them as .debs, and carries patches only while they are in flight upstream (each patch links its upstream PR).

| Component | Upstream | Pin |
|---|---|---|
| MMDVM-Host | [g4klx/MMDVM-Host](https://github.com/g4klx/MMDVM-Host) | _Phase 0: pending first pin_ |
| DMRGateway | [g4klx/DMRGateway](https://github.com/g4klx/DMRGateway) | pending |
| YSFGateway / DGIdGateway | [g4klx/YSFClients](https://github.com/g4klx/YSFClients) | pending |
| P25Gateway | [g4klx/P25Clients](https://github.com/g4klx/P25Clients) | pending |
| NXDNGateway | [g4klx/NXDNClients](https://github.com/g4klx/NXDNClients) | pending |
| DAPNETGateway | [g4klx/DAPNETGateway](https://github.com/g4klx/DAPNETGateway) | pending |
| APRSGateway | [g4klx/APRSGateway](https://github.com/g4klx/APRSGateway) | pending |
| DStarGateway | [g4klx/DStarGateway](https://github.com/g4klx/DStarGateway) | pending |
| MMDVMCal | [g4klx/MMDVMCal](https://github.com/g4klx/MMDVMCal) | pending |

All upstream components GPL-2.0-or-later; build scripts here GPL-3.0.

First milestone: `build.yml` compiles MMDVM-Host (MQTT era) + DMRGateway for all three arches and publishes artifacts. Tracked in [waypoint#5](https://github.com/KN4OQW/waypoint/issues/5) (MQTT-native status pipeline).
