# waypoint-stack

Pinned, reproducibly-built g4klx digital voice daemons for [Waypoint](https://github.com/KN4OQW/waypoint).

Upstream moved to an MQTT data plane in May 2026 (MMDVM-Host rename, libmosquitto requirement). This repo pins exact upstream commits, builds them for amd64/arm64/armhf in public CI, packages them as .debs, and carries patches only while they are in flight upstream (each patch links its upstream PR).

| Component | Upstream | Pin |
|---|---|---|
| MMDVM-Host | [KN4OQW/MMDVM-Host](https://github.com/KN4OQW/MMDVM-Host) (fork of g4klx) | `71e598c` (g4klx `43edd65` + M17 restored + deferred CW Id) |
| DMRGateway | [g4klx/DMRGateway](https://github.com/g4klx/DMRGateway) | `79edbc4` (MQTT era) |
| YSFGateway (+ DGIdGateway, YSFParrot) | [g4klx/YSFClients](https://github.com/g4klx/YSFClients) | `2b480aa` (MQTT era) |
| P25Gateway (+ P25Parrot) | [g4klx/P25Clients](https://github.com/g4klx/P25Clients) | `9751c6e` (MQTT era) |
| NXDNGateway (+ NXDNParrot) | [g4klx/NXDNClients](https://github.com/g4klx/NXDNClients) | `18b4e9a` (MQTT era) |
| DAPNETGateway | [g4klx/DAPNETGateway](https://github.com/g4klx/DAPNETGateway) | `5527546` (MQTT era) |
| APRSGateway | [g4klx/APRSGateway](https://github.com/g4klx/APRSGateway) | pending |
| DStarGateway | [g4klx/DStarGateway](https://github.com/g4klx/DStarGateway) | `612f388` (MQTT era) |
| M17Gateway | [g4klx/M17Gateway](https://github.com/g4klx/M17Gateway) | `c72b989` (pre-MQTT) |
| MMDVMCal | [g4klx/MMDVMCal](https://github.com/g4klx/MMDVMCal) | pending |

All upstream components GPL-2.0-or-later; build scripts here GPL-3.0.

CI compiles the pinned stack — MMDVM-Host (M17 fork), DMRGateway, YSFGateway/DGIdGateway (+ YSFParrot), P25Gateway (+ P25Parrot), NXDNGateway (+ NXDNParrot), DStarGateway, M17Gateway, and DAPNETGateway — for all three arches and publishes `.deb` artifacts. That is every daemon Waypoint's eight modes need. Still to pin/build: APRSGateway and MMDVMCal. Tracked in [waypoint#5](https://github.com/KN4OQW/waypoint/issues/5) (MQTT-native status pipeline).

The **MMDVM_CM** cross-mode bridges are no longer on that list. Waypoint retired the per-bridge surface in favour of the RFC-0003 bus (a named bus with modes attached, rather than a daemon per mode pair), so those binaries are never needed — see `docs/config-coverage.md` §3 in the waypoint repo.

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

Daemon packages are versioned `1:0~git<upstream-date>.<7-sha>+wp<n>`:

- `1:` is the **epoch** — see [Why there is an epoch](#why-there-is-an-epoch).
- `<upstream-date>` is the pinned commit's own date, `YYYYMMDD`. It is what makes the version **ordered**.
- `<7-sha>` is the upstream commit the binary was built from (the `pins.env` SHA), so the package version names its exact source.
- `+wp<n>` is the Waypoint packaging revision against that same pin. It increments for packaging-only changes (a dependency fix, a doc change) and resets to `wp1` whenever the pin moves.

The `0~git` prefix sorts *below* any future real upstream release version, so a tagged upstream release will always upgrade cleanly over these snapshots.

The `waypoint-stack` metapackage (`arch: all`) carries a single stack version (currently `0.3.0`) and depends on the **exact** versions of every daemon package, epoch included. Installing it pulls the whole stack at one known-good version set; bump its version whenever any daemon package changes. The metapackage needs no epoch of its own — plain semver was already ordered.

#### Why the date is there

The version used to be `0~git<7-sha>+wp<n>`, with nothing in it that tracked time. A git SHA is not ordered, so those versions sorted essentially at random:

```console
$ dpkg --compare-versions '0~gitfd4a6a4+wp1' gt '0~git5527546+wp1' && echo 'fd4a6a4 > 5527546'
fd4a6a4 > 5527546
$ dpkg --compare-versions '0~git2b480aa+wp1' lt '0~git9751c6e+wp1' && echo '2b480aa < 9751c6e'
2b480aa < 9751c6e
```

That was invisible while the published repo carried exactly one version of each package — with one candidate, there is nothing to order. It stops being invisible the moment the pool [retains previous versions](#pool-retention), which it now does: apt's candidate is the **highest-sorting** version available, so a newer build whose SHA happened to sort low would never be offered as an upgrade, and `apt list --upgradable` — which is what drives waypointd's whole update plan — could even present an older build as an update. The date makes "newest" and "highest" the same thing again.

#### Why there is an epoch

Adding the date is not by itself a version *increase*. `dpkg` compares the leading non-digit run first, so a SHA beginning with a letter sorts **above** the date form:

```console
$ dpkg --compare-versions '0~git20250709.c72b989+wp1' gt '0~gitc72b989+wp1' || echo 'the new version is LOWER'
the new version is LOWER
```

Two packages were in exactly that position (`waypoint-mmdvmhost`, `waypoint-m17gateway`), and they could never have upgraded to the new scheme. The epoch is Debian's mechanism for precisely this — a versioning change that would otherwise go backwards — and `1:` clears it unconditionally. It is carried forever from here on; do not drop it.

### Packages

| Package | Binary (`/usr/bin/`) | Upstream | Pin |
|---|---|---|---|
| `waypoint-mmdvmhost` | `MMDVM-Host` | [KN4OQW/MMDVM-Host](https://github.com/KN4OQW/MMDVM-Host) (fork of g4klx) | `71e598c` |
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
| `waypoint-dapnetgateway` | `DAPNETGateway` | [g4klx/DAPNETGateway](https://github.com/g4klx/DAPNETGateway) | `5527546` |
| `waypoint-stack` | *(metapackage, `arch: all`)* | — | pins all of the above at exact versions |

### Dependencies

Runtime dependencies are **measured, not guessed** — `dpkg-shlibdeps` against the built armhf binaries. The MQTT daemons (MMDVM-Host, DMRGateway, the YSF/DG-ID/P25/NXDN gateways, dstargateway) depend on `libc6`, `libgcc-s1`, `libmosquitto1` and `libstdc++6`. `M17Gateway` and the parrots do not link `libmosquitto1` (`M17Gateway` is pre-MQTT; the parrots are local echo). Nothing links a Boost runtime library, so no Boost dependency is declared; `libssl3` is pulled transitively through `libmosquitto1`.

### Pool retention

The published `pool/` keeps the **current version plus three previous ones**, per package per architecture (`KEEP_VERSIONS`, default 4, in [`packaging/publish-apt.sh`](packaging/publish-apt.sh)).

This is not housekeeping — it is the apt-side half of a safety guarantee. `waypointd`'s stack updater is confirm-or-revert: it health-gates an update and, on failure, rolls back with `apt-get install <the previously installed versions>`. That only works if those versions are still downloadable. For a long time they were not — this script rebuilt the tree from only the current build's `.deb`s, so the repo carried exactly one version of each package, and a node whose update installed cleanly and then failed its health check was stranded on the new version with no way back ([waypoint#221](https://github.com/KN4OQW/waypoint/issues/221)).

Because GitHub Pages deploys from a workflow artifact rather than a branch, the previously published `.deb`s live in exactly one place: the site itself. So each publish **fetches the live pool from `BASE_URL` and merges the new build over it**, then prunes to `KEEP_VERSIONS` using `dpkg --compare-versions` (never a filename sort — see [Why the date is there](#why-the-date-is-there)).

That inherit step is load-bearing, so **a failed fetch is fatal**: degrading quietly to a one-version pool would look like a successful publish while silently restoring the bug. A genuine first publish of a new repository is the one legitimate exception, and it must say so explicitly with `ALLOW_EMPTY_POOL=1`.

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

This repository ships **no unit files**. Every `.deb` here carries a daemon binary and nothing else; configuration and units are rendered and managed by waypointd, and the units themselves are installed by the Waypoint image.

That was not always true in practice. `systemd/waypoint-bus@.service` — the templated unit for an RFC-0003 mode bus — lived here, outside every `nfpm.yaml`, so no package installed it and no node ever received it. It has moved to the image alongside the eleven gateway units, together with the `waypoint-bus` binary it names, which was likewise never built or released ([waypoint#109](https://github.com/KN4OQW/waypoint/issues/109)). Anything that needs to reach a node needs a delivery mechanism; a file in this repo is not one.
