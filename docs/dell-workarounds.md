# Dell P2425H local build

This checkout includes the earlier Dell scaling/default-layout patch and the
standalone HDMI DDC transport, brightness-key routing, and cursor refresh fixes.
The tested desktop is 2304 × 1296 HiDPI (4608 × 2592 backing), mirrored onto a
1920 × 1080 Dell at 100 Hz. The laptop remains the main display below the Dell.

## Cursor

A standalone mirrored virtual screen reproduced the sticking/jumping cursor at
both 100 Hz and 60 Hz, even with Crisp absent and touching screen edges. The same
layout worked in BetterDisplay. A tiny redraw on the source screen resolved the
symptom in the user's live test at 100 Hz.

`MirroredCursorRefreshService` maintains a one-point, 1%-opacity, click-through
panel per owned mirror source. It polls pointer position at 60 Hz and changes the
panel only on movement. It does not warp the cursor, intercept input, or request
Accessibility access. Mirror teardown removes its panels, observer, and timer.
Screen-parameter notifications reposition the panels.

Background: [BetterDisplay issue #807](https://github.com/waydabber/BetterDisplay/issues/807#issuecomment-2593772073).

## Brightness

Crisp controls the Dell's physical backlight directly, without BetterDisplay
running or installed. On the tested M1 HDMI connection, ordinary IOAVService
DDC at chip address `0x37` acknowledges requests but returns DDC NULL frames.
The HDMI bridge transport uses `0xB7` with the same DDC packet and checksum.
A standalone probe verified brightness writes and matching readback at 60, 85,
and 100 with BetterDisplay closed. The installed Crisp build then passed hardware
readback at 0, 10, 25, 50, 75, and 100 (three replies each), with software factor
1.0 throughout. The panel was restored to 50 afterward.

`DDCTransport` probes the bridge only after a standard DDC NULL reply. It requires
a successful brightness response with valid header, checksum, and current/max
range before permitting bridge writes. The selected transport is cached per
display and invalidated with its channel. Inconclusive probes retry after a
20-second cooldown rather than latching a wake-time failure forever. Normal and write-only DDC routes retain
the standard address. All operations use the existing per-display DDC queue.
This relies on private IOAVService behavior and needs regression testing on
other Apple Silicon HDMI connections.

The optional `crisp.hardwareOnlyBrightnessUUIDs` array selects physical panels
whose SDR slider should use the complete hardware 0–100 range without software
preview or extra gamma dimming below 15%. It is enabled locally for the Dell.
Zero means the monitor's minimum backlight, not a black image. Hardware dimming
includes the hardware cursor and coexists with f.lux colour adjustment. The
normal failure fallback and HDR software route remain available.

The optional `crisp.forceSoftwareBrightnessUUIDs` preference remains for panels
whose transport cannot control hardware. It is **disabled for this Dell**. Its
`SoftwareDimmingService` uses a click-through black panel with a 5% floor,
following the physical panel's current mirror source. This avoids gamma-table
competition with f.lux but does not darken the hardware cursor. Panels are
removed at 100%, on disconnect, or on quit; UUID checks reject stale writes.

## Brightness keys

With “Follow the pointer”, AppKit reports the virtual source under the pointer,
while Crisp's display list contains the physical Dell. The previous direct-ID
lookup failed and passed the key through to macOS, changing the built-in panel.
`BrightnessDisplayRouting` now resolves a unique physical owner for a live,
Crisp-owned mirror source. Native screens keep their direct match; unknown,
inactive, and ambiguous mirrors keep the existing fallback. The same mapping
serves custom brightness shortcuts, and the brightness HUD uses the rendering
screen. “All displays” and selected-display routing are unchanged.

The regression harness `scripts/check-brightness-routing.swift` fails on the
old direct-only lookup and passes eight routing cases with the fix. Equivalent
XCTest coverage lives in `CrispTests/BrightnessDisplayRoutingTests.swift`.

## Checks

The app compiles with the macOS Command Line Tools and Swift 6. The focused
checks in `scripts/check-dell-workarounds.swift` exercise the actual persistence
model. `scripts/check-mirrored-cursor-refresh.swift` checks cursor-panel lifecycle.
`scripts/check-software-dimming.swift` checks
brightness opacity, the safety floor, click-through behavior, display-ID
validation, screen reconfiguration, and removal. Commands are in their headers.

`scripts/check-ddc-transport.swift` exercises bounded negotiation and rejects
malformed bridge replies; equivalent XCTest coverage is in `DDCTransportTests`.

The normal `make test` command could not run here: xcodegen/full Xcode are absent.
A temporary Swift Package attempt also failed because XCTest is unavailable in
this Command Line Tools installation. Do not interpret the focused checks as a
complete XCTest-suite run. Full-screen Spaces and physical sleep/wake remain
manual follow-up checks.

Official app updates replace this custom binary; automatic updates are disabled
in the local preferences, and `./dev.sh` preserves that policy on every rebuild.
Rebuild from this checkout to retain these changes. Manual upstream installation
still replaces the custom app.

## Maintaining this fork

Keep the local maintenance branch separate from upstream `main`. Fetch upstream
changes, merge them into the maintenance branch, resolve conflicts, and rebuild
with `./dev.sh`; do not install the upstream binary over the fork. The script
updates the existing `/Applications/Crisp.app` and does not create a second app.
Run `make check` on a Mac with Xcode, xcodegen, and SwiftLint before publishing.

For contribution, keep transport negotiation, mirror-aware brightness-key
routing, and cursor refresh in independent commits/PRs. The experimental Dell
resolution stops, saved default setup, software fallback, and hardware-only
preference can remain on the maintenance branch until their broader behavior
has been exercised. Do not publish `build/` diagnostics or machine preferences.

Local preferences are keyed by the physical panel's CoreGraphics UUID, not its
transient display ID. `crisp.hardwareOnlyBrightnessUUIDs` and
`crisp.forceSoftwareBrightnessUUIDs` are arrays of UUID strings read at launch;
restart Crisp after changing them. For a hardware-only panel, remove it from the
forced-software array and clear its saved `crisp.softBrightness.uuid.<UUID>` to
`1.0` before restarting so a previous software fallback does not remain dimmed.

Ad-hoc signing changes the app identity on rebuild and may require refreshing
Crisp's existing Accessibility grant for brightness keys. A stable local code
signing identity named `Crisp Dev` avoids that repeated step; see `dev.sh`.
