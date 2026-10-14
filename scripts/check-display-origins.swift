// swiftc -parse-as-library Crisp/Models/DisplayOrigins.swift \
//   scripts/check-display-origins.swift -o /tmp/crisp-origin-checks && /tmp/crisp-origin-checks
import Foundation

@main
struct DisplayOriginChecks {
    static func main() {
        let grouped = DisplayOrigins.coalesced([(1, 0, 0), (1, 0, 0), (3, 1920, 0)])!
        precondition(grouped.count == 2 && grouped[0].id == 1 && grouped[1].id == 3)
        precondition(DisplayOrigins.coalesced([(1, 0, 0), (1, 10, 0)]) == nil)
        precondition(DisplayOrigins.coalesced([]) == nil)
        let moved = DisplayOrigins.coalesced([(1, -100, -200), (1, -100, -200), (3, 0, 0)])!
        precondition(moved[0].x == -100 && moved[0].y == -200 && moved[1].x == 0)
        print("PASS: mirror-origin grouping, conflicting positions, empty layout, main translation")
    }
}
