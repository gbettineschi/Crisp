// swiftc -swift-version 6 -parse-as-library Crisp/Services/SoftwareDimmingService.swift \
//   scripts/check-software-dimming.swift -o /tmp/crisp-dimming-checks && /tmp/crisp-dimming-checks
import AppKit

@main
struct SoftwareDimmingChecks {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let firstID = NSScreen.screens.first!.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! CGDirectDisplayID
        let id = CommandLine.arguments.dropFirst().first.flatMap(UInt32.init) ?? firstID
        let source = CGDisplayMirrorsDisplay(id)
        let renderingID = source == kCGNullDirectDisplay ? id : source
        let screen = NSScreen.screens.first {
            $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID == renderingID
        }!
        let uuid = CFUUIDCreateString(nil, CGDisplayCreateUUIDFromDisplayID(id)!.takeRetainedValue())! as String
        let service = SoftwareDimmingService.shared
        defer { service.removeAll() }
        let initial = Set(app.windows.map(ObjectIdentifier.init))
        func windows() -> [NSWindow] {
            app.windows.filter { !initial.contains(ObjectIdentifier($0)) && $0.isVisible }
        }
        service.setFactor(0.5, for: id, uuid: uuid)
        precondition(windows().count == 1)
        let panel = windows()[0]
        precondition(panel.frame == screen.frame)
        precondition(panel.ignoresMouseEvents && !panel.canBecomeKey && !panel.canBecomeMain)
        precondition(abs(panel.alphaValue - 0.5) < 0.001)
        service.setFactor(0.25, for: id, uuid: uuid)
        precondition(windows().count == 1 && windows()[0] === panel)
        precondition(abs(panel.alphaValue - 0.75) < 0.001)
        service.setFactor(0, for: id, uuid: uuid)
        precondition(abs(panel.alphaValue - 0.95) < 0.001)
        service.setFactor(0.5, for: id, uuid: "stale-panel")
        precondition(abs(panel.alphaValue - 0.95) < 0.001, "Stale ID write changed dimming")
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        precondition(windows().count == 1 && windows()[0].frame == screen.frame)
        service.setFactor(1, for: id, uuid: uuid)
        precondition(windows().isEmpty)
        service.setFactor(0.5, for: UInt32.max, uuid: uuid)
        precondition(windows().isEmpty)
        service.setFactor(0.5, for: id, uuid: uuid)
        service.remove(for: id)
        precondition(windows().isEmpty)
        service.removeAll()
        print("PASS: full-range opacity, 5% floor, click-through, screen bounds, reuse, stale-ID rejection, reconfiguration, removal")
    }
}
