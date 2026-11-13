import CoreGraphics
import Foundation

struct SystemHotCornerModifier: Equatable {
    let rawValue: UInt64

    private static let knownFlags: CGEventFlags = [
        .maskShift,
        .maskControl,
        .maskAlternate,
        .maskCommand
    ]

    init(dockValue: Int) {
        rawValue = dockValue > 0 ? UInt64(dockValue) : 0
    }

    var eventFlags: CGEventFlags {
        CGEventFlags(rawValue: rawValue).intersection(Self.knownFlags)
    }

    var hasUnknownBits: Bool {
        rawValue & ~Self.knownFlags.rawValue != 0
    }

    var usesEmergencyOptionKey: Bool {
        eventFlags.contains(.maskAlternate)
    }

    func matches(current flags: CGEventFlags) -> Bool {
        guard !hasUnknownBits else { return false }
        return flags.intersection(eventFlags) == eventFlags
    }

    func symbols(language: AppLanguage) -> String {
        var values: [String] = []
        if eventFlags.contains(.maskShift) { values.append("⇧") }
        if eventFlags.contains(.maskControl) { values.append("⌃") }
        if eventFlags.contains(.maskAlternate) { values.append("⌥") }
        if eventFlags.contains(.maskCommand) { values.append("⌘") }
        if hasUnknownBits {
            values.append(L10n.text(language, ja: "不明", en: "Unknown"))
        }
        return values.joined()
    }
}
