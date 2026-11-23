import AppKit
import CoreGraphics
import Foundation

enum Corner: String, CaseIterable, Codable, Identifiable {
    case topLeft, topRight, bottomLeft, bottomRight

    var id: String { rawValue }

    func title(language: AppLanguage) -> String { L10n.corner(self, language: language) }
}

enum SettingsTab: String, CaseIterable, Hashable, Identifiable {
    case cornersAndLayout
    case barrierAndBehavior
    case safetyAndDiagnostics

    var id: String { rawValue }
}

enum CornerBarrierPolicy: String, CaseIterable, Codable, Identifiable {
    case enabled
    case stopperOnly
    case disabled

    var id: String { rawValue }

    func title(language: AppLanguage) -> String { L10n.barrierPolicy(self, language: language) }
}

enum BarrierPassThroughMode: String, CaseIterable, Codable, Identifiable {
    case alwaysBlock
    case speedBump

    var id: String { rawValue }

    func title(language: AppLanguage) -> String { L10n.passThroughMode(self, language: language) }
}

enum SuppressionScope: String, CaseIterable, Codable, Identifiable {
    case actionsOnly
    case barriersAndActions

    var id: String { rawValue }

    func title(language: AppLanguage) -> String { L10n.suppressionScope(self, language: language) }
}

enum CornerModifierRequirement: String, CaseIterable, Codable, Identifiable {
    case none
    case command
    case control
    case shift
    case controlCommand
    case shiftCommand
    case controlShift

    var id: String { rawValue }

    var requiredFlags: CGEventFlags {
        switch self {
        case .none: []
        case .command: [.maskCommand]
        case .control: [.maskControl]
        case .shift: [.maskShift]
        case .controlCommand: [.maskControl, .maskCommand]
        case .shiftCommand: [.maskShift, .maskCommand]
        case .controlShift: [.maskControl, .maskShift]
        }
    }

    var symbols: String {
        switch self {
        case .none: ""
        case .command: "⌘"
        case .control: "⌃"
        case .shift: "⇧"
        case .controlCommand: "⌃⌘"
        case .shiftCommand: "⇧⌘"
        case .controlShift: "⌃⇧"
        }
    }

    func matches(current flags: CGEventFlags) -> Bool {
        let required = requiredFlags
        guard !required.isEmpty else { return true }
        return flags.intersection(required) == required
    }

    func title(language: AppLanguage) -> String { L10n.modifierRequirement(self, language: language) }
}

enum CornerAction: String, CaseIterable, Codable, Identifiable {
    case systemHotCorner
    case none
    case missionControl
    case applicationWindows
    case showDesktop
    case launchpad
    case quickNote
    case notificationCenter
    case lockScreen
    case startScreenSaver
    case putDisplayToSleep
    case screenshotSelection
    case screenshotPanel
    case openApplication
    case runShortcut
    case testNotification

    var id: String { rawValue }

    func title(language: AppLanguage) -> String { L10n.action(self, language: language) }
}

struct CornerAssignment: Codable, Hashable {
    var displayID: String
    var corner: Corner
    var action: CornerAction
    var barrierPolicy: CornerBarrierPolicy = .enabled
    var modifierRequirement: CornerModifierRequirement = .none
    var customApplicationPath: String?
    var customShortcutName: String?

    var key: String { "\(displayID):\(corner.rawValue)" }

    private enum CodingKeys: String, CodingKey {
        case displayID
        case corner
        case action
        case barrierPolicy
        case modifierRequirement
        case customApplicationPath
        case customShortcutName
    }

    init(
        displayID: String,
        corner: Corner,
        action: CornerAction = .systemHotCorner,
        barrierPolicy: CornerBarrierPolicy = .enabled,
        modifierRequirement: CornerModifierRequirement = .none,
        customApplicationPath: String? = nil,
        customShortcutName: String? = nil
    ) {
        self.displayID = displayID
        self.corner = corner
        self.action = action
        self.barrierPolicy = barrierPolicy
        self.modifierRequirement = modifierRequirement
        self.customApplicationPath = customApplicationPath
        self.customShortcutName = customShortcutName
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        displayID = try values.decode(String.self, forKey: .displayID)
        corner = try values.decode(Corner.self, forKey: .corner)
        action = try values.decodeIfPresent(CornerAction.self, forKey: .action) ?? .systemHotCorner
        barrierPolicy = try values.decodeIfPresent(CornerBarrierPolicy.self, forKey: .barrierPolicy) ?? .enabled
        modifierRequirement = try values.decodeIfPresent(CornerModifierRequirement.self, forKey: .modifierRequirement) ?? .none
        customApplicationPath = try values.decodeIfPresent(String.self, forKey: .customApplicationPath)
        customShortcutName = try values.decodeIfPresent(String.self, forKey: .customShortcutName)
    }
}

struct Preferences: Codable, Equatable {
    var appLanguage: AppLanguage = .japanese
    var isEnabled = false
    var barrierEnabled = false
    var barrierLength: Double = 40
    var passThroughMode: BarrierPassThroughMode = .alwaysBlock
    var speedBumpHoldMilliseconds: Double = 300
    var pauseInFullscreenApps = false
    var excludedBundleIdentifiers: [String] = []
    var suppressionScope: SuppressionScope = .actionsOnly
    var zoneSize: Double = 40
    var dwellMilliseconds: Double = 200
    var assignments: [CornerAssignment] = []

    init() {}

    private enum CodingKeys: String, CodingKey {
        case appLanguage
        case isEnabled
        case barrierEnabled
        case barrierLength
        case passThroughMode
        case speedBumpHoldMilliseconds
        case pauseInFullscreenApps
        case excludedBundleIdentifiers
        case suppressionScope
        case zoneSize
        case dwellMilliseconds
        case assignments
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        appLanguage = try values.decodeIfPresent(AppLanguage.self, forKey: .appLanguage) ?? .japanese
        isEnabled = try values.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        barrierEnabled = try values.decodeIfPresent(Bool.self, forKey: .barrierEnabled) ?? false
        barrierLength = try values.decodeIfPresent(Double.self, forKey: .barrierLength) ?? 40
        passThroughMode = try values.decodeIfPresent(BarrierPassThroughMode.self, forKey: .passThroughMode) ?? .alwaysBlock
        speedBumpHoldMilliseconds = try values.decodeIfPresent(Double.self, forKey: .speedBumpHoldMilliseconds) ?? 300
        pauseInFullscreenApps = try values.decodeIfPresent(Bool.self, forKey: .pauseInFullscreenApps) ?? false
        excludedBundleIdentifiers = try values.decodeIfPresent([String].self, forKey: .excludedBundleIdentifiers) ?? []
        suppressionScope = try values.decodeIfPresent(SuppressionScope.self, forKey: .suppressionScope) ?? .actionsOnly
        zoneSize = try values.decodeIfPresent(Double.self, forKey: .zoneSize) ?? 40
        dwellMilliseconds = try values.decodeIfPresent(Double.self, forKey: .dwellMilliseconds) ?? 200
        assignments = try values.decodeIfPresent([CornerAssignment].self, forKey: .assignments) ?? []
    }

    func assignment(displayID: String, corner: Corner) -> CornerAssignment {
        assignments.first { $0.displayID == displayID && $0.corner == corner }
            ?? CornerAssignment(displayID: displayID, corner: corner)
    }

    func action(displayID: String, corner: Corner) -> CornerAction {
        assignment(displayID: displayID, corner: corner).action
    }

    func barrierAction(displayID: String, corner: Corner) -> CornerAction {
        action(displayID: displayID, corner: corner)
    }

    func barrierPolicy(displayID: String, corner: Corner) -> CornerBarrierPolicy {
        assignment(displayID: displayID, corner: corner).barrierPolicy
    }

    func modifierRequirement(displayID: String, corner: Corner) -> CornerModifierRequirement {
        assignment(displayID: displayID, corner: corner).modifierRequirement
    }

    func customApplicationPath(displayID: String, corner: Corner) -> String? {
        assignment(displayID: displayID, corner: corner).customApplicationPath
    }

    func customShortcutName(displayID: String, corner: Corner) -> String? {
        assignment(displayID: displayID, corner: corner).customShortcutName
    }

    mutating func updateAssignment(
        displayID: String,
        corner: Corner,
        _ mutate: (inout CornerAssignment) -> Void
    ) {
        if let index = assignments.firstIndex(where: { $0.displayID == displayID && $0.corner == corner }) {
            mutate(&assignments[index])
        } else {
            var created = CornerAssignment(displayID: displayID, corner: corner)
            mutate(&created)
            assignments.append(created)
        }
    }

    mutating func setAction(_ action: CornerAction, displayID: String, corner: Corner) {
        updateAssignment(displayID: displayID, corner: corner) { $0.action = action }
    }

    mutating func setBarrierPolicy(_ policy: CornerBarrierPolicy, displayID: String, corner: Corner) {
        updateAssignment(displayID: displayID, corner: corner) { $0.barrierPolicy = policy }
    }

    mutating func setModifierRequirement(_ requirement: CornerModifierRequirement, displayID: String, corner: Corner) {
        updateAssignment(displayID: displayID, corner: corner) { $0.modifierRequirement = requirement }
    }

    mutating func setCustomApplicationPath(_ path: String?, displayID: String, corner: Corner) {
        updateAssignment(displayID: displayID, corner: corner) { $0.customApplicationPath = path }
    }

    mutating func setCustomShortcutName(_ name: String?, displayID: String, corner: Corner) {
        updateAssignment(displayID: displayID, corner: corner) { $0.customShortcutName = name }
    }
}

struct DisplayDescriptor: Identifiable, Hashable {
    /// ColorSync display UUID, used instead of CGDirectDisplayID because the latter may change after restart.
    let id: String
    let displayNumber: UInt32
    let name: String
    let frame: CGRect
}

struct HotZone: Identifiable, Equatable {
    let displayID: String
    let displayName: String
    let corner: Corner
    let rect: CGRect

    var id: String { "\(displayID):\(corner.rawValue)" }
}
