import AppKit
import Foundation

enum Corner: String, CaseIterable, Codable, Identifiable {
    case topLeft, topRight, bottomLeft, bottomRight

    var id: String { rawValue }

    func title(language: AppLanguage) -> String { L10n.corner(self, language: language) }
}

enum CornerAction: String, CaseIterable, Codable, Identifiable {
    case systemHotCorner, none, missionControl, applicationWindows, showDesktop, launchpad, testNotification

    var id: String { rawValue }

    func title(language: AppLanguage) -> String { L10n.action(self, language: language) }
}

struct CornerAssignment: Codable, Hashable {
    var displayID: String
    var corner: Corner
    var action: CornerAction

    var key: String { "\(displayID):\(corner.rawValue)" }
}

struct Preferences: Codable {
    var appLanguage: AppLanguage = .japanese
    var isEnabled = false
    var barrierEnabled = false
    var barrierLength: Double = 40
    var zoneSize: Double = 40
    var dwellMilliseconds: Double = 200
    var assignments: [CornerAssignment] = []

    init() {}

    private enum CodingKeys: String, CodingKey {
        case appLanguage, isEnabled, barrierEnabled, barrierLength, zoneSize, dwellMilliseconds, assignments
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        appLanguage = try values.decodeIfPresent(AppLanguage.self, forKey: .appLanguage) ?? .japanese
        isEnabled = try values.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        barrierEnabled = try values.decodeIfPresent(Bool.self, forKey: .barrierEnabled) ?? false
        barrierLength = try values.decodeIfPresent(Double.self, forKey: .barrierLength) ?? 40
        zoneSize = try values.decodeIfPresent(Double.self, forKey: .zoneSize) ?? 40
        dwellMilliseconds = try values.decodeIfPresent(Double.self, forKey: .dwellMilliseconds) ?? 200
        assignments = try values.decodeIfPresent([CornerAssignment].self, forKey: .assignments) ?? []
    }

    func action(displayID: String, corner: Corner) -> CornerAction {
        assignments.first { $0.displayID == displayID && $0.corner == corner }?.action ?? .systemHotCorner
    }

    func barrierAction(displayID: String, corner: Corner) -> CornerAction {
        action(displayID: displayID, corner: corner)
    }

    mutating func setAction(_ action: CornerAction, displayID: String, corner: Corner) {
        assignments.removeAll { $0.displayID == displayID && $0.corner == corner }
        assignments.append(.init(displayID: displayID, corner: corner, action: action))
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
