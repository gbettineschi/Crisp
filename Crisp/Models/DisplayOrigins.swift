import Foundation

/// Mirrored physical outputs share one desktop and must be configured only once.
enum DisplayOrigins {
    typealias Origin = (id: UInt32, x: Int, y: Int)

    static func coalesced(_ proposed: [Origin]) -> [Origin]? {
        guard !proposed.isEmpty else { return nil }
        var origins: [Origin] = []
        for origin in proposed {
            if let existing = origins.first(where: { $0.id == origin.id }) {
                guard existing.x == origin.x, existing.y == origin.y else { return nil }
            } else {
                origins.append(origin)
            }
        }
        return origins
    }
}
