import AppKit
import Combine
import CoreGraphics
import Foundation
import os.log

/// Restores an explicitly saved resolution/layout after a real connection change or wake.
/// Changes made while working are temporary until Save is pressed; this is not a layout lock.
@MainActor
final class DefaultDisplaySetupService: ObservableObject {
    static let shared = DefaultDisplaySetupService()
    private static let log = Logger(subsystem: "com.crisp.app", category: "defaultsetup")
    private let store = DefaultDisplaySetupStore()

    @Published private(set) var savedSetup: DefaultDisplaySetup?
    @Published private(set) var isRestoring = false
    @Published private(set) var status: String?

    private var restoreTask: Task<Void, Never>?
    private var generation: UInt64 = 0
    private var lastPhysicalIDs: Set<CGDirectDisplayID> = []

    private init() {
        savedSetup = store.load()
    }

    private func physicalDisplays(in manager: DisplayManager) -> [DisplayInfo] {
        manager.displays.filter {
            $0.isOnline && !VirtualDisplayService.shared.isVirtualDisplay($0.displayID)
                && !PhysicalDisplayToggleService.shared.isDisconnected(uuid: $0.displayUUID)
        }
    }

    /// Called on every topology refresh. Creating our own virtual does not count as docking.
    func displaysChanged(in manager: DisplayManager) {
        let ids = Set(physicalDisplays(in: manager).map(\.displayID))
        guard ids != lastPhysicalIDs else { return }
        lastPhysicalIDs = ids
        requestRestore(in: manager)
    }

    /// Cancels scheduled restore and waits for an in-flight CG operation to return before
    /// a user's resolution/arrangement action begins, so an old restore cannot win the race.
    func prepareForUserChange() async -> Bool {
        let previous = cancelPendingRestore()
        await previous?.value
        let ready = await CGHelpers.waitForPendingOperations()
        if !ready { status = String(localized: "macOS is still applying a display change. Try again shortly.") }
        return ready
    }

    @discardableResult
    private func cancelPendingRestore() -> Task<Void, Never>? {
        generation &+= 1
        let previous = restoreTask
        // Keep the draining task visible to concurrent manual actions.
        previous?.cancel()
        isRestoring = false
        return previous
    }

    func saveCurrent(in manager: DisplayManager) async {
        guard await prepareForUserChange() else { return }
        let displays = physicalDisplays(in: manager)
        var entries: [DefaultDisplaySetup.Entry] = []
        var sourceIDs = Set<CGDirectDisplayID>()
        for display in displays {
            let source = effectiveDisplayID(for: display)
            guard sourceIDs.insert(source).inserted,
                  let mode = CGDisplayCopyDisplayMode(source) else {
                status = String(localized: "Could not capture this setup. Use separate desktops for physical displays.")
                return
            }
            let bounds = CGDisplayBounds(source)
            guard bounds.origin.x.isFinite, bounds.origin.y.isFinite,
                  let x = Int(exactly: bounds.origin.x.rounded()),
                  let y = Int(exactly: bounds.origin.y.rounded()) else {
                status = String(localized: "Could not capture the display positions.")
                return
            }
            entries.append(.init(uuid: display.displayUUID, width: mode.width, height: mode.height,
                                 isHiDPI: mode.pixelWidth > mode.width, x: x, y: y,
                                 isMain: CGDisplayIsMain(source) != 0 || CGDisplayIsMain(display.displayID) != 0))
        }
        let value = DefaultDisplaySetup(displays: entries)
        do {
            try store.save(value)
            savedSetup = value
            status = String(localized: "Default saved: resolution, arrangement and main display.")
        } catch {
            status = String(localized: "Could not save this setup. Wait for the displays to settle and try again.")
        }
    }

    func clear() async {
        guard await prepareForUserChange() else { return }
        store.clear()
        savedSetup = nil
        status = String(localized: "Default cleared. The current display settings are unchanged.")
    }

    func hasMatchingDefault(in manager: DisplayManager) -> Bool {
        savedSetup?.matches(uuids: physicalDisplays(in: manager).map(\.displayUUID)) == true
    }

    /// Three attempts with delays; no endless retries and no action on another monitor set.
    func requestRestore(in manager: DisplayManager) {
        let previous = cancelPendingRestore()
        guard !PresetService.shared.isApplying, let setup = savedSetup,
              setup.matches(uuids: physicalDisplays(in: manager).map(\.displayUUID)) else { return }
        let token = generation
        restoreTask = Task { @MainActor [weak self, weak manager] in
            await previous?.value
            guard let self, let manager else { return }
            defer {
                if self.generation == token {
                    self.restoreTask = nil
                    self.isRestoring = false
                }
            }
            for delay: UInt64 in [1_000_000_000, 2_000_000_000, 4_000_000_000] {
                do { try await Task.sleep(nanoseconds: delay) } catch { return }
                guard await CGHelpers.waitForPendingOperations() else {
                    if self.generation == token {
                        self.status = String(localized: "macOS is still applying a display change. Try again shortly.")
                    }
                    return
                }
                guard self.canRestore(setup, in: manager, token: token) else { return }
                self.isRestoring = true
                if await self.apply(setup, in: manager, token: token) {
                    guard self.canRestore(setup, in: manager, token: token) else { return }
                    self.status = String(localized: "Saved default restored.")
                    return
                }
                guard self.canRestore(setup, in: manager, token: token) else { return }
            }
            Self.log.error("Saved default could not be restored after three attempts")
            self.status = String(localized: "Could not restore the default. Check the displays, then press Restore default.")
        }
    }

    private func canRestore(_ setup: DefaultDisplaySetup, in manager: DisplayManager, token: UInt64) -> Bool {
        generation == token && !Task.isCancelled
            && setup.matches(uuids: physicalDisplays(in: manager).map(\.displayUUID))
    }

    private func effectiveDisplayID(for display: DisplayInfo) -> CGDirectDisplayID {
        display.renderingDisplayID
    }

    private func apply(_ setup: DefaultDisplaySetup, in manager: DisplayManager, token: UInt64) async -> Bool {
        for entry in setup.displays {
            guard canRestore(setup, in: manager, token: token),
                  let display = physicalDisplays(in: manager).first(where: { $0.displayUUID == entry.uuid }),
                  !display.availableModes.isEmpty else { return false }
            guard await applyResolution(entry, to: display, setup: setup, in: manager, token: token),
                  canRestore(setup, in: manager, token: token) else { return false }
            display.currentDisplayMode = DisplayMode.currentMode(for: effectiveDisplayID(for: display))
        }

        // Resolve IDs AFTER every mode switch. A mirror's virtual source is the layout
        // participant; positioning the physical mirror target can be ignored by macOS.
        guard canRestore(setup, in: manager, token: token) else { return false }
        var origins: [(id: CGDirectDisplayID, x: Int, y: Int)] = []
        for entry in setup.displays {
            guard let display = physicalDisplays(in: manager).first(where: { $0.displayUUID == entry.uuid })
            else { return false }
            origins.append((effectiveDisplayID(for: display), entry.x, entry.y))
        }
        guard Set(origins.map(\.id)).count == origins.count,
              await ArrangementService.shared.restorePositions(origins) else { return false }
        guard canRestore(setup, in: manager, token: token) else { return false }
        for display in physicalDisplays(in: manager) {
            let source = effectiveDisplayID(for: display)
            display.bounds = CGDisplayBounds(source)
            display.isMain = CGDisplayIsMain(source) != 0 || CGDisplayIsMain(display.displayID) != 0
        }
        // Verify actual modes and geometry, rather than only trusting transaction success.
        return setup.displays.allSatisfy { entry in
            guard let display = physicalDisplays(in: manager).first(where: { $0.displayUUID == entry.uuid }),
                  let mode = CGDisplayCopyDisplayMode(effectiveDisplayID(for: display)) else { return false }
            let source = effectiveDisplayID(for: display)
            let bounds = CGDisplayBounds(source)
            let isMain = CGDisplayIsMain(source) != 0 || CGDisplayIsMain(display.displayID) != 0
            return mode.width == entry.width && mode.height == entry.height
                && (mode.pixelWidth > mode.width) == entry.isHiDPI
                && abs(bounds.origin.x - CGFloat(entry.x)) < 1
                && abs(bounds.origin.y - CGFloat(entry.y)) < 1 && isMain == entry.isMain
        }
    }

    private func applyResolution(_ entry: DefaultDisplaySetup.Entry, to display: DisplayInfo,
                                 setup: DefaultDisplaySetup, in manager: DisplayManager,
                                 token: UInt64) async -> Bool {
        let mirror = MirroredModeService.shared
        let needsVirtual = entry.isHiDPI && MirroredModeService.beyondCapStops(for: display)
            .contains { $0.width == entry.width && $0.height == entry.height }
        if needsVirtual {
            let source = mirror.virtualDisplayID(for: display.displayID)
            let current = source.flatMap { CGDisplayCopyDisplayMode($0) }
            let matches = current?.width == entry.width && current?.height == entry.height
                && current?.pixelWidth == entry.width * 2
                && source == CGDisplayMirrorsDisplay(display.displayID)
            if !matches, !(await mirror.apply(display: display, width: entry.width, height: entry.height)) {
                return false
            }
        } else {
            if mirror.isActive(for: display.displayID), !(await mirror.restore(display: display)) { return false }
            guard canRestore(setup, in: manager, token: token) else { return false }
            let physicalID = display.displayID
            let modes = await Task.detached(priority: .userInitiated) {
                DisplayMode.availableModes(for: physicalID)
            }.value
            guard canRestore(setup, in: manager, token: token),
                  let target = modes.filter({
                      $0.width == entry.width && $0.height == entry.height && $0.isHiDPI == entry.isHiDPI
                  }).max(by: { $0.refreshRate < $1.refreshRate }) else { return false }
            let current = CGDisplayCopyDisplayMode(physicalID)
            if current?.width != entry.width || current?.height != entry.height
                || (current.map { $0.pixelWidth > $0.width } != entry.isHiDPI) {
                guard await ResolutionService.shared.setDisplayMode(target, for: physicalID, restoringDefault: true) else { return false }
            }
        }
        guard canRestore(setup, in: manager, token: token) else { return false }
        return true
    }
}
