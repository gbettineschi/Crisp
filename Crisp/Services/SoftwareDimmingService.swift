import AppKit

/// Dims explicitly software-controlled panels without competing with f.lux or
/// other transfer-table writers. Ownership follows the physical panel's UUID;
/// the window follows its current mirror source's AppKit coordinates.
@MainActor
final class SoftwareDimmingService {
    static let shared = SoftwareDimmingService()

    private struct Entry {
        let uuid: String
        var factor: Double
        var window: NSPanel?
    }
    private var entries: [CGDirectDisplayID: Entry] = [:]

    private init() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(refresh),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
    }

    private func uuid(for id: CGDirectDisplayID) -> String? {
        guard CGDisplayIsOnline(id) != 0,
              let value = CGDisplayCreateUUIDFromDisplayID(id) else { return nil }
        return CFUUIDCreateString(nil, value.takeRetainedValue()) as String?
    }

    func setFactor(_ factor: Double, for id: CGDirectDisplayID, uuid: String) {
        guard factor.isFinite, self.uuid(for: id) == uuid else { return }
        let clamped = min(1, max(0.05, factor))
        guard clamped < 1 else { remove(for: id); return }
        if let entry = entries[id], entry.uuid != uuid { remove(for: id) }
        var entry = entries[id] ?? Entry(uuid: uuid, factor: clamped)
        entry.factor = clamped
        entries[id] = entry
        refresh()
    }

    func remove(for id: CGDirectDisplayID) {
        entries.removeValue(forKey: id)?.window?.close()
    }

    func removeAll() {
        for id in Array(entries.keys) { remove(for: id) }
    }

    @objc private func refresh() {
        for id in Array(entries.keys) {
            guard var entry = entries[id] else { continue }
            guard uuid(for: id) == entry.uuid else { remove(for: id); continue }
            let source = CGDisplayMirrorsDisplay(id)
            let renderingID = source == kCGNullDirectDisplay ? id : source
            guard let screen = NSScreen.screens.first(where: {
                $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                    as? CGDirectDisplayID == renderingID
            }) else {
                entry.window?.close()
                entry.window = nil
                entries[id] = entry
                continue
            }
            let window: NSPanel
            if let existing = entry.window {
                window = existing
                if window.frame != screen.frame { window.setFrame(screen.frame, display: true) }
            } else {
                window = NSPanel(contentRect: screen.frame,
                                 styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.hidesOnDeactivate = false
                window.isOpaque = false
                window.hasShadow = false
                window.backgroundColor = .black
                window.ignoresMouseEvents = true
                window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
                window.collectionBehavior = [.stationary, .canJoinAllSpaces,
                    .ignoresCycle, .canJoinAllApplications, .fullScreenAuxiliary]
                entry.window = window
            }
            window.alphaValue = 1 - entry.factor
            if !window.isVisible { window.orderFrontRegardless() }
            entries[id] = entry
        }
    }
}
