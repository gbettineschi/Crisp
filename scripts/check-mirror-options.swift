// swiftc -parse-as-library Crisp/Models/MirrorWorkaroundOptions.swift \
//   scripts/check-mirror-options.swift -o /tmp/crisp-mirror-options && /tmp/crisp-mirror-options
import Foundation

@main
struct MirrorOptionChecks {
    static func main() {
        let suite = "crisp.mirror-options.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        precondition(!MirrorWorkaroundOptions.refreshCursor(uuid: "panel", defaults: defaults))
        precondition(MirrorWorkaroundOptions.sizes(uuid: "panel", nativeWidth: 1920,
                                                  nativeHeight: 1080, defaults: defaults).isEmpty)
        defaults.set(["panel"], forKey: "crisp.cursorRefreshUUIDs")
        precondition(MirrorWorkaroundOptions.refreshCursor(uuid: "panel", defaults: defaults))
        precondition(!MirrorWorkaroundOptions.refreshCursor(uuid: "other", defaults: defaults))
        defaults.set(["panel": [2560, 2048, 2304, 2304, -1, 0, Int.max, 1920]],
                     forKey: "crisp.experimentalHiDPIWidthsByUUID")
        let sizes = MirrorWorkaroundOptions.sizes(uuid: "panel", nativeWidth: 1920,
                                                   nativeHeight: 1080, defaults: defaults)
        precondition(sizes.map(\.width) == [2048, 2304, 2560])
        precondition(sizes.map(\.height) == [1152, 1296, 1440])
        precondition(MirrorWorkaroundOptions.sizes(uuid: "other", nativeWidth: 1920,
                                                  nativeHeight: 1080, defaults: defaults).isEmpty)
        precondition(MirrorWorkaroundOptions.sizes(uuid: "panel", nativeWidth: 0,
                                                  nativeHeight: 1080, defaults: defaults).isEmpty)
        print("PASS: mirror workarounds default off, UUID isolation, aspect ratio, bounds, deduplication")
    }
}
