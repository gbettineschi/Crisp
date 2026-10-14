import Foundation

/// Experimental mirror options are explicit per-display opt-ins, never vendor guesses.
enum MirrorWorkaroundOptions {
    static func refreshCursor(uuid: String, defaults: UserDefaults = .standard) -> Bool {
        defaults.stringArray(forKey: "crisp.cursorRefreshUUIDs")?.contains(uuid) == true
    }

    static func sizes(uuid: String, nativeWidth: Int, nativeHeight: Int,
                      defaults: UserDefaults = .standard) -> [(width: Int, height: Int)] {
        guard nativeWidth > 0, nativeHeight > 0,
              let widths = defaults.dictionary(forKey: "crisp.experimentalHiDPIWidthsByUUID")?[uuid] as? [Int]
        else { return [] }
        // Bound the experimental backing to 8192 pixels per axis and the mode count.
        // Availability still depends on macOS/GPU support; configuration is not a guarantee.
        return Set(widths).sorted().compactMap { width in
            guard width > nativeWidth, width <= 4096 else { return nil }
            let height = (Double(width) * Double(nativeHeight) / Double(nativeWidth)).rounded()
            guard height >= 1, height <= 4096 else { return nil }
            return (width: width, height: Int(height))
        }.prefix(16).map { $0 }
    }
}
