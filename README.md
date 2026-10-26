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

Requires **macOS 14+**. The personal release is universal for Apple silicon and Intel.

```sh
brew tap gbettineschi/tap
brew install --cask gbettineschi/tap/crisp-personal
```

Moving from an existing copy? Quit Crisp first. If installed through the upstream cask, run `brew uninstall --cask crisp` without `--zap`; otherwise move the old app bundle to Trash. Keep preferences and other app data, then install this cask.

Or download `Crisp-personal.zip` from [this fork's releases](https://github.com/gbettineschi/Crisp/releases). Quit Crisp before replacing the app. Turn off upstream automatic updates in an existing copy before switching; the packaged fork disables the upstream feed so updates come through this tap.

The build is ad-hoc signed and not notarized; macOS may require **Open Anyway** in Privacy & Security. Brightness keys need Accessibility access, which can require renewed approval after an update. Preferences are shared with upstream because the bundle ID is unchanged. Keep app data when changing installations. `brew install --cask crisp` installs upstream.

## Update

```sh
brew update
brew upgrade --cask gbettineschi/tap/crisp-personal
```

Official changes must be reviewed and merged into this fork before releasing. They are not merged automatically. Homebrew does not create a background update schedule.

## Build and release

Source builds require full Xcode with a macOS 26+ SDK and a matching Swift 6 compiler.

```sh
git clone https://github.com/gbettineschi/Crisp.git
cd Crisp
bash scripts/package-personal.sh v1.7.1
```

Output: `dist/Crisp-personal.zip`. This builds without installing or launching the app. The upstream `make build` path retains its upstream Sparkle configuration; use the personal packaging script for this fork.

To release, commit and push reviewed source to this fork, then tag it `vX.Y.Z` and push the tag. **Release personal Mac build** packages the universal app, publishes the ZIP and checksum, and updates [the shared tap](https://github.com/gbettineschi/homebrew-tap) automatically. No Apple signing secrets are needed. `TAP_DEPLOY_KEY` grants write access only to that tap. To retry just the catalog, run **Update Homebrew tap** with the already published tag. Publish a new version instead of replacing an existing asset.

Routine CI tests and builds without uploading installers. Tagged releases publish downloads directly to GitHub Releases; no duplicate Actions installer artifact is kept.

## Development

`bash scripts/check-maintenance.sh` runs the focused fork checks. `make check` runs the broader upstream checks and needs Xcode, XcodeGen and SwiftLint. See [build instructions](docs/BUILDING.md) and [fork verification notes](docs/dell-workarounds.md#audit-and-reproducible-checks) for their limits.

## Credits and license

[MIT](LICENSE). This fork builds on [Crisp](https://github.com/didriksg/Crisp), which began as a fork of [FreeDisplay](https://github.com/huberdf/FreeDisplay). Original notices are retained in [ACKNOWLEDGMENTS.md](ACKNOWLEDGMENTS.md).
