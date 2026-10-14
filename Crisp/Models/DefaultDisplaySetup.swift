import Foundation

/// A user-selected default for one exact set of physical display identities.
/// Virtual IDs and mode IDs are deliberately not persisted: both change on reconnect.
struct DefaultDisplaySetup: Codable, Equatable {
    struct Entry: Codable, Equatable {
        var uuid: String
        var width: Int
        var height: Int
        var isHiDPI: Bool
        var x: Int
        var y: Int
        var isMain: Bool
    }

    var displays: [Entry]

    var isValid: Bool {
        guard !displays.isEmpty,
              Set(displays.map(\.uuid)).count == displays.count,
              displays.filter(\.isMain).count == 1 else { return false }
        return displays.allSatisfy {
            !$0.uuid.isEmpty && (1...16384).contains($0.width) && (1...16384).contains($0.height)
                && Int32(exactly: $0.x) != nil && Int32(exactly: $0.y) != nil
                && (!$0.isMain || ($0.x == 0 && $0.y == 0))
        }
    }

    func matches(uuids: [String]) -> Bool {
        isValid && uuids.count == displays.count && Set(uuids) == Set(displays.map(\.uuid))
    }
}

@MainActor
struct DefaultDisplaySetupStore {
    static let key = "crisp.defaultDisplaySetup"
    var defaults: UserDefaults = .standard

    enum SaveError: Error { case invalidSetup }

    func load() -> DefaultDisplaySetup? {
        guard let data = defaults.data(forKey: Self.key),
              let value = try? JSONDecoder().decode(DefaultDisplaySetup.self, from: data),
              value.isValid else { return nil }
        return value
    }

    func save(_ value: DefaultDisplaySetup) throws {
        guard value.isValid else { throw SaveError.invalidSetup }
        defaults.set(try JSONEncoder().encode(value), forKey: Self.key)
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}
