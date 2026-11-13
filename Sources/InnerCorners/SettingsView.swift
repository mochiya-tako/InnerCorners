import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section(model.text(ja: "言語", en: "Language")) {
                Picker(model.text(ja: "UI言語", en: "UI Language"), selection: Binding(
                    get: { model.preferences.appLanguage },
                    set: { model.setLanguage($0) }
                )) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.selectionTitle).tag(language)
                    }
                }
                .pickerStyle(.segmented)
                Text(model.text(ja: "変更はすぐに反映され、次回起動時にも維持されます。", en: "Changes take effect immediately and persist after restart."))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section(model.text(ja: "接合部ソフトバリア", en: "Junction Barrier")) {
                Toggle(model.text(ja: "内側角に一方向の壁を作る", en: "Block passage through inner corners"), isOn: $model.preferences.barrierEnabled)
                LabeledContent(model.text(ja: "壁の長さ", en: "Barrier Length")) {
                    HStack {
                        Slider(value: $model.preferences.barrierLength, in: 10...100, step: 1)
                        Text("\(Int(model.preferences.barrierLength)) pt").monospacedDigit().frame(width: 55)
                    }
                }
                Text(model.barrierStatus)
                Text(model.text(
                    ja: "壁がオンの間は、アクション設定・発動状態・前面アプリに関係なく内部コーナーを通過できません。画面内側へ離れて同じ角へ再衝突すると、Mission Control等をキャンセルできます。",
                    en: "While enabled, inner corners remain impassable regardless of action settings, activation state, or the frontmost app. Move inward and hit the same corner again to cancel Mission Control or a similar action."
                )).font(.caption).foregroundStyle(.secondary)
                Text(model.text(
                    ja: "緊急解除：Optionキーを押しながら動かすと一時的に通過できます。画面スリープと実際のディスプレイ構成変更では古い座標の壁を停止し、安全な画面内位置へ移動してから再開します。",
                    en: "Emergency bypass: hold Option while moving to pass through temporarily. After display sleep or a real display-layout change, old barriers stop and resume only after the pointer reaches a safe on-screen position."
                )).font(.caption).foregroundStyle(.orange)
                LabeledContent(model.text(ja: "キーボード緊急終了", en: "Keyboard Emergency Quit"), value: model.emergencyHotKeyStatus)
                Text(model.text(
                    ja: "⌃⌥⌘Qは壁をオフとして保存してからアプリを終了します。Dockまたは⌘TabでInnerCornersを選び、⌘Qで終了することもできます。",
                    en: "⌃⌥⌘Q saves the barrier as off, then quits the app. You can also select InnerCorners from the Dock or with ⌘Tab and press ⌘Q."
                )).font(.caption).foregroundStyle(.orange)
            }

            Section(model.text(ja: "動作", en: "Behavior")) {
                Toggle(model.text(ja: "独自の領域アクションを有効にする", en: "Enable custom activation zones"), isOn: $model.preferences.isEnabled)
                LabeledContent(model.text(ja: "反応範囲", en: "Activation Area")) {
                    HStack {
                        Slider(value: $model.preferences.zoneSize, in: 10...100, step: 1)
                        Text("\(Int(model.preferences.zoneSize)) pt").monospacedDigit().frame(width: 55)
                    }
                }
                LabeledContent(model.text(ja: "滞留時間", en: "Dwell Time")) {
                    HStack {
                        Slider(value: $model.preferences.dwellMilliseconds, in: 0...500, step: 10)
                        Text("\(Int(model.preferences.dwellMilliseconds)) ms").monospacedDigit().frame(width: 65)
                    }
                }
                LabeledContent(model.text(ja: "macOSの権限表示", en: "macOS Permission Status")) {
                    Label(
                        model.accessibilityGranted ? model.text(ja: "許可を検出", en: "Detected") : model.text(ja: "許可を未検出", en: "Not Detected"),
                        systemImage: model.accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    ).foregroundStyle(model.accessibilityGranted ? .green : .orange)
                }
                LabeledContent(model.text(ja: "実際のカーソル制御", en: "Actual Cursor Control")) {
                    Label(
                        model.cursorControlActive
                            ? model.text(ja: "動作中", en: "Active")
                            : (model.preferences.barrierEnabled
                                ? model.text(ja: "動作していません", en: "Not Active")
                                : model.text(ja: "壁がオフ", en: "Barrier Off")),
                        systemImage: model.cursorControlActive ? "checkmark.circle.fill" : "circle"
                    ).foregroundStyle(model.cursorControlActive ? .green : (model.preferences.barrierEnabled ? .red : .secondary))
                }
                Button(model.text(ja: "アクセシビリティ権限を開く…", en: "Open Accessibility Settings…")) { model.requestAccessibilityPermission() }
                Button(model.text(ja: "テスト音を鳴らす（権限不要）", en: "Play Test Sound (No Permission Required)")) { model.runTestSound() }
                Text(model.text(
                    ja: "macOSの権限表示が未検出でも、実際のカーソル制御が「動作中」なら壁は有効です。独自の領域を検出するだけなら権限は不要です。",
                    en: "If Actual Cursor Control is Active, the barrier is working even when macOS permission is not detected. Detecting custom activation zones alone does not require permission."
                )).font(.caption).foregroundStyle(.secondary)
            }

            Section(model.text(ja: "画面配置と反応領域", en: "Display Layout and Activation Zones")) {
                DisplayLayoutView(displays: model.displays, zoneSize: model.preferences.zoneSize, hoveredZoneID: model.hoveredZoneID, language: model.language)
                Text(model.text(
                    ja: "青枠が画面、緑が反応領域です。現在ポインタが入っている領域はオレンジで表示されます。",
                    en: "Blue outlines are displays, green areas are activation zones, and the zone under the pointer appears orange."
                )).font(.caption).foregroundStyle(.secondary)
            }

            ForEach(model.displays) { display in
                Section(model.text(ja: "\(display.name)（画面 \(display.displayNumber)）のホットコーナー", en: "Hot Corners for \(display.name) (Display \(display.displayNumber))")) {
                    ForEach(Corner.allCases) { corner in
                        Picker(model.cornerTitle(corner), selection: Binding(
                            get: { model.barrierAction(displayID: display.id, corner: corner) },
                            set: { model.setAction($0, displayID: display.id, corner: corner) }
                        )) {
                            ForEach(CornerAction.allCases) { action in
                                Text(model.actionTitle(action)).tag(action)
                            }
                        }
                        Text(model.effectiveActionDescription(displayID: display.id, corner: corner))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Section(model.text(ja: "診断", en: "Diagnostics")) {
                LabeledContent(model.text(ja: "バージョン", en: "Version"), value: model.versionDescription)
                LabeledContent(model.text(ja: "認識画面", en: "Detected Displays"), value: model.text(ja: "\(model.displays.count)台", en: "\(model.displays.count)"))
                LabeledContent(model.text(ja: "方向別の壁", en: "Directional Barriers"), value: model.text(ja: "\(model.barrierCount)本", en: "\(model.barrierCount)"))
                if model.recentEvents.isEmpty {
                    Text(model.text(ja: "発動履歴はありません", en: "No activation history")).foregroundStyle(.secondary)
                } else {
                    ForEach(Array(model.recentEvents.prefix(8).enumerated()), id: \.offset) { _, event in
                        Text(event).font(.caption).textSelection(.enabled)
                    }
                }
                HStack {
                    Button(model.text(ja: "診断情報をコピー", en: "Copy Diagnostics")) { model.copyDiagnostics() }
                    Button(model.text(ja: "履歴を消去", en: "Clear History")) { model.clearDiagnostics() }
                        .disabled(model.recentEvents.isEmpty)
                }
                Text(model.text(
                    ja: "診断情報には版番号、macOS、権限、画面ID・座標、最近20件の発動結果が含まれます。",
                    en: "Diagnostics include the version, macOS, permission status, display IDs and coordinates, and the 20 most recent activation results."
                )).font(.caption).foregroundStyle(.secondary)
            }

            Section(model.text(ja: "状態", en: "Status")) {
                Text(model.status)
                LabeledContent(model.text(ja: "現在のポインタ判定", en: "Current Pointer Detection"), value: model.pointerStatus)
                LabeledContent(model.text(ja: "前面アプリ", en: "Frontmost App"), value: model.frontmostApplicationName)
                Text(model.text(
                    ja: "この表示はアプリを有効にしなくても更新されます。接合部の左右へポインタを置いて判定を確認できます。",
                    en: "This status updates even when custom actions are disabled. Place the pointer on either side of a junction to check detection."
                )).font(.caption).foregroundStyle(.secondary)
                Text(model.text(
                    ja: "ログイン項目への登録状態はmacOSのシステム設定で管理します。壁への衝突時だけカーソルを対象画面の境界内へ補正します。",
                    en: "Manage login-item status in macOS System Settings. The pointer is corrected inside the target display only when it collides with a barrier."
                )).font(.caption).foregroundStyle(.secondary)
                Text(model.text(
                    ja: "独自の領域アクションはドラッグ中に発動しません。接合部の壁はドラッグ中もカーソル通過を検出します。",
                    en: "Custom zone actions do not activate while dragging. Junction barriers continue to detect pointer passage during a drag."
                )).font(.caption).foregroundStyle(.secondary)
            }
        }
        .id(model.language)
        .formStyle(.grouped)
        .environment(\.locale, Locale(identifier: model.language.localeIdentifier))
        .frame(minWidth: 620, minHeight: 560)
        .onAppear { model.setSettingsVisible(true) }
        .onDisappear { model.setSettingsVisible(false) }
    }
}
