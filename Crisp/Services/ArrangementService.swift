import Foundation
import CoreGraphics

/// Service for reading and setting display positions in the global coordinate space.
/// On macOS, the display whose bounds contain origin (0, 0) is the main display
/// (the one that shows the Dock and menu bar).
@MainActor
class ArrangementService {
    static let shared = ArrangementService()
    private init() {}

    /// Moves the given display to the specified position in the global coordinate space.
    /// Used by preset restore, which writes each display's saved absolute origin.
    @discardableResult
    func setPosition(x: Int, y: Int, for displayID: CGDirectDisplayID) async -> Bool {
        guard await DefaultDisplaySetupService.shared.prepareForUserChange() else { return false }
        PresetService.shared.noteManualChange()
        return await applyOrigins([(displayID, x, y)])
    }

    /// Moves `displayID` to (x, y) for an interactive drag, keeping the main display pinned
    /// at (0, 0): macOS silently renormalizes any config that leaves it off origin, so this
    /// sets every display's origin in one transaction and subtracts the main's proposed
    /// origin from all of them, matching the native Arrange Displays sheet.
    @discardableResult
    func setPosition(x: Int, y: Int, for displayID: CGDirectDisplayID,
                     among displays: [DisplayInfo]) async -> Bool {
        guard await DefaultDisplaySetupService.shared.prepareForUserChange() else { return false }
        PresetService.shared.noteManualChange()

        // Moving one member moves its whole mirror group.
        let draggedSource = displays.first(where: { $0.displayID == displayID })?.renderingDisplayID
        var origins: [(id: CGDirectDisplayID, x: Int, y: Int)] = displays.map { d in
            d.renderingDisplayID == draggedSource
                ? (d.displayID, x, y)
                : (d.displayID, Int(d.bounds.origin.x), Int(d.bounds.origin.y))
        }
        // Renormalize so the current main sits at (0, 0). When the main is the
        // dragged display, this pushes its offset onto all the others.
        if let mainID = displays.first(where: { $0.isMain })?.displayID,
           let main = origins.first(where: { $0.id == mainID }),
           main.x != 0 || main.y != 0 {
            let dx = main.x, dy = main.y
            origins = origins.map { ($0.id, $0.x - dx, $0.y - dy) }
        }
        return await applyOrigins(origins)
    }

    /// Makes the target the main display by translating every display by the same vector,
    /// so the relative arrangement is preserved and only the origin moves; swapping just the
    /// target and old-main origins (the previous approach) could overlap a wider display.
    @discardableResult
    func setAsMainDisplay(_ targetID: CGDirectDisplayID, among displays: [DisplayInfo]) async -> Bool {
        guard await DefaultDisplaySetupService.shared.prepareForUserChange() else { return false }
        guard let target = displays.first(where: { $0.displayID == targetID }),
              !target.isMain else {
            return false
        }
        PresetService.shared.noteManualChange()

        let dx = Int(target.bounds.origin.x)
        let dy = Int(target.bounds.origin.y)
        let origins: [(id: CGDirectDisplayID, x: Int, y: Int)] = displays.map {
            ($0.displayID, Int($0.bounds.origin.x) - dx, Int($0.bounds.origin.y) - dy)
        }
        return await applyOrigins(origins)
    }

    /// Default restoration positions every desktop in one transaction after resolution changes.
    func restorePositions(_ origins: [(id: CGDirectDisplayID, x: Int, y: Int)]) async -> Bool {
        await applyOrigins(origins, scope: .forSession)
    }

    /// Physical user arrangements are permanent; virtual layouts are restored from our saved default.
    private func applyOrigins(_ proposed: [(id: CGDirectDisplayID, x: Int, y: Int)],
                              scope: CGConfigureOption = .permanently) async -> Bool {
        let mapped = proposed.map { origin in
            let source = CGDisplayMirrorsDisplay(origin.id)
            return (id: source == kCGNullDirectDisplay ? origin.id : source, x: origin.x, y: origin.y)
        }
        guard let origins = DisplayOrigins.coalesced(mapped) else { return false }
        // Virtual identities cannot be committed as permanent hardware configuration.
        let commitScope: CGConfigureOption = origins.contains {
            VirtualDisplayService.shared.isVirtualDisplay($0.id)
        } ? .forSession : scope
        return await CGHelpers.runWithTimeout(seconds: 10, fallback: false) {
            var config: CGDisplayConfigRef?
            guard CGBeginDisplayConfiguration(&config) == .success,
                  let cfg = config else { return false }
            for o in origins {
                guard let x = Int32(exactly: o.x), let y = Int32(exactly: o.y),
                      CGConfigureDisplayOrigin(cfg, o.id, x, y) == .success else {
                    CGCancelDisplayConfiguration(cfg)
                    return false
                }
            }
            let result = CGCompleteDisplayConfiguration(cfg, commitScope)
            if result != .success {
                CGCancelDisplayConfiguration(cfg)
                return false
            }
            return true
        }
    }
}
