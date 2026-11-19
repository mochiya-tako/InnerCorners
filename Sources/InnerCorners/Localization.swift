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

    static func barrierPolicy(_ policy: CornerBarrierPolicy, language: AppLanguage) -> String {
        switch (policy, language) {
        case (.enabled, .japanese): "壁あり＋アクション"
        case (.stopperOnly, .japanese): "壁のみ（ストッパー専用）"
        case (.disabled, .japanese): "壁なし（通過を許可）"
        case (.enabled, .english): "Barrier + Action"
        case (.stopperOnly, .english): "Barrier Only (Stopper)"
        case (.disabled, .english): "No Barrier (Allow Passage)"
        }
    }

    static func passThroughMode(_ mode: BarrierPassThroughMode, language: AppLanguage) -> String {
        switch (mode, language) {
        case (.alwaysBlock, .japanese): "常時遮断（Optionキーでのみ通過）"
        case (.speedBump, .japanese): "スピードバンプ（押し続けると通過）"
        case (.alwaysBlock, .english): "Always Block (Pass with Option)"
        case (.speedBump, .english): "Speed Bump (Push Through)"
        }
    }

    static func suppressionScope(_ scope: SuppressionScope, language: AppLanguage) -> String {
        switch (scope, language) {
        case (.actionsOnly, .japanese): "アクションのみ抑止（壁は維持）"
        case (.barriersAndActions, .japanese): "壁とアクションの両方を一時停止"
        case (.actionsOnly, .english): "Suppress Actions Only (Keep Barriers)"
        case (.barriersAndActions, .english): "Pause Both Barriers and Actions"
        }
    }

    static func modifierRequirement(_ requirement: CornerModifierRequirement, language: AppLanguage) -> String {
        switch (requirement, language) {
        case (.none, .japanese): "なし（常時発火）"
        case (.none, .english): "None (Always Trigger)"
        case (.command, _): "⌘ Command"
        case (.control, _): "⌃ Control"
        case (.shift, _): "⇧ Shift"
        case (.controlCommand, _): "⌃⌘ Control + Command"
        case (.shiftCommand, _): "⇧⌘ Shift + Command"
        case (.controlShift, _): "⌃⇧ Control + Shift"
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
        case (.screenshotSelection, .japanese): "スクリーンショット（範囲選択）"
        case (.screenshotPanel, .japanese): "スクリーンショットパネル（収録/撮影）"
        case (.openApplication, .japanese): "指定したアプリを起動"
        case (.runShortcut, .japanese): "ショートカット.appを実行"
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
        case (.screenshotSelection, .english): "Screenshot (Selection)"
        case (.screenshotPanel, .english): "Screenshot & Recording Panel"
        case (.openApplication, .english): "Open Custom Application"
        case (.runShortcut, .english): "Run macOS Shortcut"
        case (.testNotification, .english): "Test Sound (No Keystrokes)"
        }
    }
}
