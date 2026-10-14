# Display maintenance fork

This fork was developed with **OpenAI Codex**, including implementation, tests,
and code review. The locally exercised setup is an M1 Pro HDMI connection to a
Dell P2425H: 2304 × 1296 logical HiDPI (4608 × 2592 backing), 100 Hz, with the
built-in display below it as the main display. BetterDisplay is not required.
This is a tested configuration, not a claim of support for arbitrary hardware.

## Contribution status

Upstream PRs [#229](https://github.com/didriksg/Crisp/pull/229),
[#230](https://github.com/didriksg/Crisp/pull/230), and
[#231](https://github.com/didriksg/Crisp/pull/231) are **closed and withdrawn**.
Their descriptions disclose Codex assistance. Their remote contribution branches
were deleted. The complete fork is maintained on `main` in
[gbettineschi/Crisp](https://github.com/gbettineschi/Crisp/tree/main); upstream
`didriksg/Crisp` is unchanged.
No upstream acceptance is requested. Reopening contributions requires full CI and
broader hardware/lifecycle validation, not just a successful local build.

## Hardware brightness and keys

The tested HDMI bridge acknowledges ordinary IOAVService requests at `0x37` but
returns DDC NULL replies. A valid brightness reply at `0xB7` identifies the usable
bridge transport. Negotiation is not tied to a manufacturer or model number.

Only an ordinary, quarantine-aware brightness read can negotiate after a NULL
reply. Writes and capabilities requests never initiate negotiation reads. Valid
standard and bridge transports are cached with the current channel; topology
changes clear them. Unconfirmed bridge selection has a 20-second retry cooldown,
subject to the existing read quarantine. Replies must pass header, length,
checksum, command, and value-range checks. This uses private IOAVService behavior;
other HDMI bridges and write-only monitors still need physical validation.

`crisp.hardwareOnlyBrightnessUUIDs` is an array of physical display UUIDs. For an
opted-in SDR monitor, the slider maps the complete 0–100 range to hardware DDC,
without the normal below-15% gamma dimming or speculative software preview.
Zero means minimum backlight, not black. Failure fallback and HDR routing remain
available. Restoring a saved dim clears it only when SDR is positively confirmed;
unavailable HDR information preserves it. Identity gamma is not repeatedly written
on ordinary DDC adjustments, avoiding unnecessary interference with f.lux.

The experimental black-window dimming backend was removed during audit. It could
dim an entire mirror group, stack multiple overlays, and interfere with brightness
boost. `crisp.forceSoftwareBrightnessUUIDs` is no longer read. The upstream gamma
fallback remains. Hardware dimming includes the cursor; software dimming does not
necessarily do so.

Brightness keys resolve a Crisp-owned mirror source to its unique physical owner.
Native screens retain direct matching; ambiguous, unknown, or inactive mirrors
retain the existing fallback. The same routing serves custom shortcuts, and the
HUD uses the rendering screen. The user previously confirmed that “Follow the
pointer” targets the Dell after refreshing the app's Accessibility grant.

## Optional mirror workarounds

Both options are explicit per-display preferences; no Dell vendor check remains.
Use the physical UUID reported by `crispctl display list`, not its transient ID.
Restart Crisp after changing these settings.

- `crisp.cursorRefreshUUIDs`: array of UUID strings. Default: empty. Enables a
  one-point, 1%-opacity, click-through redraw panel on that monitor's Crisp-owned
  mirror source. Pointer position is polled at 60 Hz; redraw occurs on movement.
  Teardown removes panels, observer, and timer. This resolved cursor crossing in
  the user's 2304 × 1296 / 100 Hz test. Fullscreen Spaces, sleep/wake, and power
  consumption have not been established across hardware.
- `crisp.experimentalHiDPIWidthsByUUID`: dictionary from UUID to integer width
  arrays. Default: empty. Heights follow the native aspect ratio; widths must
  exceed native width, both logical dimensions are capped at 4096, duplicate sizes
  are removed, and at most 16 stops are used. This bounds the 2× backing to 8192
  pixels per axis. Configuring a size does not guarantee macOS/GPU support. The
  locally tested widths are 2048, 2304, and 2560 on a 1920 × 1080 panel.

Example opt-ins (replace the placeholder with a physical display UUID):

```sh
defaults write com.crisp.app crisp.cursorRefreshUUIDs -array 'DISPLAY-UUID'
defaults write com.crisp.app crisp.experimentalHiDPIWidthsByUUID -dict-add \
  'DISPLAY-UUID' '<array><integer>2048</integer><integer>2304</integer><integer>2560</integer></array>'
defaults write com.crisp.app crisp.hardwareOnlyBrightnessUUIDs -array 'DISPLAY-UUID'
```

The `-array` examples replace that preference's existing list. Existing upstream
ultrawide behavior remains available when no valid extra widths are configured.
Identical monitor virtual identities and rotated displays remain unverified.

## Saved setup and arrangement

Saving a default records resolution, HiDPI state, origins, and main display for
one exact set of display UUIDs. It is not a full hardware configuration backup:
rotation, refresh rate, HDR, and mirror topology are not saved. Ordinary physical
mirror groups cannot be captured as separate desktops. Third-party virtual
screens are not categorically excluded.

Manual resolution and arrangement changes cancel pending restores and drain
already-started CoreGraphics operations. A response timeout is distinguished from
actual operation completion; a busy drain aborts replacement work instead of
allowing a late restore to overwrite it. Restore retries also drain, and presets
suppress reconnect-triggered restores while applying. The drain wait itself is
bounded, but awaiting the preceding restore can take longer. This is not a general
transaction lock for every concurrent display action in the application.

Arrangement coalesces physical mirror members sharing the same desktop origin;
conflicting positions are rejected. Dragging one member moves its mirror group.
Restore can partially apply before an error; it does not provide atomic rollback.

## Audit and reproducible checks

On 2026-10-15, the optimized arm64 build (warnings as errors), x86_64 typecheck,
all seven focused checks in three consecutive passes, available strict lint,
XcodeGen generation, shell syntax, and whitespace checks passed. `make test`
reached xcodebuild and failed because full Xcode is not installed. The audit
binary was not installed over the working `/Applications/Crisp.app`. Local UUID
opt-ins were prepared so a later build retains the current cursor/resolution
settings. No upstream PR was reopened.

The audit found and corrected read-quarantine bypass, mirror-group dimming and
boost regressions, saved-HDR dimming loss, restore cancellation gaps, duplicate
mirror-origin rejection, and lint failures. Focused checks exercise production
models/services, not copies of their implementations:

```sh
bash scripts/check-maintenance.sh
```

This compiles seven checks with Swift 6 and warnings as errors, then runs each
three times: brightness routing, DDC negotiation, saved-layout persistence,
mirror-origin grouping, mirror-option validation, delayed CoreGraphics completion,
and cursor-panel lifecycle. The last briefly creates a one-point window; it does
not move the pointer or change display modes.

The full optimized arm64 application build, x86_64 typecheck, available strict
SwiftLint rules, shell syntax, and whitespace checks are separate checks. With
Command Line Tools, `SWIFTLINT_DISABLE_SOURCEKIT=1` skips the SourceKit-backed
`statement_position` rule. XcodeGen can generate the project, but `make test` and
compiler-based localization export require full Xcode, absent on this machine.
Do not describe focused checks as a full XCTest run or proof of no regressions.
New status strings have catalog keys; translations remain incomplete.

Earlier hardware validation covered brightness 0, 10, 25, 50, 75, and 100 with
three DDC readbacks each and software factor 1.0; those results belong to the
previous installed build. They do not substitute for hardware validation of
subsequent audit edits. Sleep/reconnect, HDR, arbitrary write-only monitors,
fullscreen Spaces, and display combinations remain manual follow-up work.

## Maintenance and updates

Keep changes on this fork’s `main`. Future updates are made here: fetch and
review upstream changes, merge the chosen changes into this fork, run the checks,
and rebuild locally. Do not update this fork through the official app updater. `./dev.sh` replaces the existing
`/Applications/Crisp.app`, without creating a second application. Run `make check`
with full Xcode, XcodeGen, and SwiftLint before publishing a contribution.
Do not publish ignored `build/` diagnostics or machine preferences.

Automatic upstream update checks and installations are disabled on this Mac.
Development builds preserve that policy by default, both in the bundle and
persisted preferences. A manual upstream install still replaces the
custom binary, and those disabled preferences survive replacement. To restore
updater defaults during a development build, use `CRISP_DISABLE_UPDATES=0 ./dev.sh`.
After installing an official upstream build, delete the two persisted overrides:

```sh
defaults delete com.crisp.app SUEnableAutomaticChecks
defaults delete com.crisp.app SUAutomaticallyUpdate
```

Ad-hoc signing can invalidate Accessibility permission on rebuild. Refresh
Crisp's existing grant if needed. A stable local signing identity named `Crisp Dev`
avoids repeated identity changes; see `dev.sh`.
