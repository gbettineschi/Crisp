// Command Line Tools-only checks (no display mode or cursor movement changes):
// swiftc -swift-version 6 -parse-as-library Crisp/Models/DefaultDisplaySetup.swift \
//   scripts/check-dell-workarounds.swift \
//   -o /tmp/crisp-dell-checks && /tmp/crisp-dell-checks
import AppKit

@main
struct DellWorkaroundChecks {
    @MainActor
    static func main() throws {
        let suite = "crisp.workaround-checks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = DefaultDisplaySetupStore(defaults: defaults)
        let setup = DefaultDisplaySetup(displays: [
            .init(uuid: "laptop", width: 1656, height: 1075, isHiDPI: true,
                  x: 0, y: 0, isMain: true),
            .init(uuid: "dell", width: 2304, height: 1296, isHiDPI: true,
                  x: -313, y: -1296, isMain: false)
        ])
        precondition(setup.matches(uuids: ["dell", "laptop"]))
        precondition(!setup.matches(uuids: ["laptop", "other"]))
        precondition(!setup.matches(uuids: ["laptop"]))
        try store.save(setup)
        precondition(DefaultDisplaySetupStore(defaults: defaults).load() == setup)
        do {
            try store.save(DefaultDisplaySetup(displays: []))
            fatalError("An invalid setup replaced the saved layout")
        } catch DefaultDisplaySetupStore.SaveError.invalidSetup { }
        precondition(store.load() == setup)
        store.clear()
        precondition(store.load() == nil)
        print("PASS: saved layout round-trip, monitor matching, invalid-save protection, clear")

    }
}
