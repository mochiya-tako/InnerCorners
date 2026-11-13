import Foundation

enum SystemHotCornerAction: Equatable {
    case none
    case missionControl
    case applicationWindows
    case showDesktop
    case startScreenSaver
    case disableScreenSaver
    case putDisplayToSleep
    case apps
    case notificationCenter
    case lockScreen
    case quickNote
    case unknown(Int)

    init(dockValue: Int) {
        switch dockValue {
        case 0: self = .none
        case 2: self = .missionControl
        case 3: self = .applicationWindows
        case 4: self = .showDesktop
        case 5: self = .startScreenSaver
        case 6: self = .disableScreenSaver
        case 10: self = .putDisplayToSleep
        case 11: self = .apps
        case 12: self = .notificationCenter
        case 13: self = .lockScreen
        case 14: self = .quickNote
        default: self = .unknown(dockValue)
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .none:
            L10n.text(language, ja: "なし", en: "None")
        case .missionControl:
            "Mission Control"
        case .applicationWindows:
            L10n.text(language, ja: "アプリケーションウインドウ", en: "Application Windows")
        case .showDesktop:
            L10n.text(language, ja: "デスクトップを表示", en: "Show Desktop")
        case .startScreenSaver:
            L10n.text(language, ja: "スクリーンセーバを開始", en: "Start Screen Saver")
        case .disableScreenSaver:
            L10n.text(language, ja: "スクリーンセーバを無効にする", en: "Disable Screen Saver")
        case .putDisplayToSleep:
            L10n.text(language, ja: "ディスプレイをスリープさせる", en: "Put Display to Sleep")
        case .apps:
            L10n.text(language, ja: "アプリ", en: "Apps")
        case .notificationCenter:
            L10n.text(language, ja: "通知センター", en: "Notification Center")
        case .lockScreen:
            L10n.text(language, ja: "ロック画面", en: "Lock Screen")
        case .quickNote:
            L10n.text(language, ja: "クイックメモ", en: "Quick Note")
        case .unknown(let value):
            L10n.text(
                language,
                ja: "不明な標準アクション（値：\(value)）",
                en: "Unknown macOS action (value: \(value))"
            )
        }
    }
}
