<img src="docs/icon.png" width="80" alt="Crisp icon">

# Crisp — personal fork

A fork of [didriksg/Crisp](https://github.com/didriksg/Crisp), made for my MacBook and Dell monitor setup. I added HDMI brightness fixes, better brightness-key routing for mirrored displays, saved display layouts, and opt-in HiDPI and cursor workarounds.

**My changes are 100% vibe-coded, for personal use, and provided as is.** No warranty or promised support. The original app is the work of its upstream authors.

Crisp is a native macOS menu-bar app for display scaling, brightness, volume, presets and virtual displays. For the original app and its signed releases, see [upstream](https://github.com/didriksg/Crisp). Those downloads do not contain this fork's patches.

## What changed

- **HDMI brightness:** detect a working DDC transport on the tested Apple silicon HDMI bridge; optional hardware-only brightness per monitor.
- **Brightness keys:** route a mirrored desktop to its physical monitor, including “follow the pointer”.
- **Saved layout:** restore display positions, the main display and selected HiDPI modes. This is a partial layout restore, not a full hardware backup.
- **Optional mirror fixes:** extra HiDPI sizes and a cursor redraw workaround, enabled per display. They are off by default.
- **Maintenance:** focused regression checks and a development installer that disables upstream automatic updates to preserve the patches.

The locally exercised setup was an M1 Pro and Dell P2425H at 2304 × 1296 logical HiDPI / 100 Hz. Other monitors, sleep/wake, HDR and display combinations still need testing. See [details and opt-in settings](docs/dell-workarounds.md).

## Install this fork

Requires **macOS 14+**, full **Xcode with a macOS 26+ SDK**, and a matching Swift 6 compiler. There is no prebuilt release of this fork yet. `brew install --cask crisp` installs upstream.

```sh
git clone https://github.com/gbettineschi/Crisp.git
cd Crisp
make build
open Crisp.dmg
```

`make build` creates an ad-hoc signed, universal Apple silicon/Intel app. Quit any running Crisp, then drag the app from the disk image into Applications, replacing the existing copy.

Before opening the fork, disable upstream automatic updates so they cannot replace your patched build:

```sh
defaults write com.crisp.app SUEnableAutomaticChecks -bool false
defaults write com.crisp.app SUAutomaticallyUpdate -bool false
open -a Crisp
```

The build is not notarized; macOS may require **Open Anyway** in System Settings → Privacy & Security. Brightness keys need Accessibility access. An ad-hoc rebuild can require renewing that permission. Settings are shared with the original app because the bundle ID is unchanged.

## Update

Review and merge wanted upstream changes into this fork, then rebuild. To get this fork's already-reviewed updates and replace an existing installation on Apple silicon:

```sh
git pull --ff-only
./dev.sh
```

`dev.sh` rebuilds, replaces `/Applications/Crisp.app` and relaunches it. It keeps upstream automatic updates disabled. On Intel, repeat `make build` and replace the app from the DMG. Installing an official Crisp release replaces the personal patches.

## Development

`bash scripts/check-maintenance.sh` runs the focused fork checks. `make check` runs the broader upstream checks and needs Xcode, XcodeGen and SwiftLint. See [build instructions](docs/BUILDING.md) and [fork verification notes](docs/dell-workarounds.md#audit-and-reproducible-checks) for their limits.

## Credits and license

[MIT](LICENSE). This fork builds on [Crisp](https://github.com/didriksg/Crisp), which began as a fork of [FreeDisplay](https://github.com/huberdf/FreeDisplay). Original notices are retained in [ACKNOWLEDGMENTS.md](ACKNOWLEDGMENTS.md).
