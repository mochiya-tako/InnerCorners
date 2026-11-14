import Foundation

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case japanese
    case english

    var id: String { rawValue }
    var localeIdentifier: String { self == .japanese ? "ja" : "en" }
    var selectionTitle: String { self == .japanese ? "日本語" : "English" }
}

enum L10n {
    static func text(_ language: AppLanguage, ja: String, en: String) -> String {
        language == .japanese ? ja : en
    }

    static func corner(_ corner: Corner, language: AppLanguage) -> String {
        switch (corner, language) {
        case (.topLeft, .japanese): "左上"
        case (.topRight, .japanese): "右上"
        case (.bottomLeft, .japanese): "左下"
        case (.bottomRight, .japanese): "右下"
        case (.topLeft, .english): "Top Left"
        case (.topRight, .english): "Top Right"
        case (.bottomLeft, .english): "Bottom Left"
        case (.bottomRight, .english): "Bottom Right"
        }
    }

    static func action(_ action: CornerAction, language: AppLanguage) -> String {
        switch (action, language) {
        case (.systemHotCorner, .japanese): "macOSの標準設定に従う"
        case (.none, .japanese): "なし"
        case (.missionControl, _): "Mission Control"
        case (.applicationWindows, .japanese): "アプリケーションウインドウ"
        case (.showDesktop, .japanese): "デスクトップを表示"
        case (.launchpad, .japanese): "アプリ"
        case (.quickNote, .japanese): "クイックメモ"
        case (.notificationCenter, .japanese): "通知センター"
        case (.lockScreen, .japanese): "ロック画面"
        case (.startScreenSaver, .japanese): "スクリーンセーバを開始"
        case (.putDisplayToSleep, .japanese): "ディスプレイをスリープさせる"
        case (.testNotification, .japanese): "テスト音（キー送信なし）"
        case (.systemHotCorner, .english): "Follow macOS Hot Corner"
        case (.none, .english): "None"
        case (.applicationWindows, .english): "Application Windows"
        case (.showDesktop, .english): "Show Desktop"
        case (.launchpad, .english): "Apps"
        case (.quickNote, .english): "Quick Note"
        case (.notificationCenter, .english): "Notification Center"
        case (.lockScreen, .english): "Lock Screen"
        case (.startScreenSaver, .english): "Start Screen Saver"
        case (.putDisplayToSleep, .english): "Put Display to Sleep"
        case (.testNotification, .english): "Test Sound (No Keystrokes)"
        }
    }
}
