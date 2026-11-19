import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            topLanguageHeaderBar
            Divider()
            TabView(selection: $model.selectedSettingsTab) {
                cornersAndLayoutTab
                    .tabItem {
                        Label(
                            model.text(ja: "コーナー＆画面配置", en: "Corners & Layout"),
                            systemImage: "rectangle.split.2x1"
                        )
                    }
                    .tag(SettingsTab.cornersAndLayout)

                barrierAndBehaviorTab
                    .tabItem {
                        Label(
                            model.text(ja: "バリア＆動作", en: "Barrier & Behavior"),
                            systemImage: "shield.lefthalf.filled"
                        )
                    }
                    .tag(SettingsTab.barrierAndBehavior)

                safetyAndDiagnosticsTab
                    .tabItem {
                        Label(
                            model.text(ja: "安全・権限・診断", en: "Safety & Diagnostics"),
                            systemImage: "wrench.and.screwdriver"
                        )
                    }
                    .tag(SettingsTab.safetyAndDiagnostics)
            }
            .id(model.language)
        }
        .environment(\.locale, Locale(identifier: model.language.localeIdentifier))
        .frame(minWidth: 680, minHeight: 640)
        .onAppear { model.setSettingsVisible(true) }
        .onDisappear { model.setSettingsVisible(false) }
    }

    private var topLanguageHeaderBar: some View {
        HStack(spacing: 12) {
            Label(
                "InnerCorners Gemini",
                systemImage: model.cursorControlActive ? "shield.checkered" : "shield"
            )
            .font(.headline)

            Text("v\(model.versionDescription)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.12), in: Capsule())

            Spacer()

            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .foregroundStyle(.secondary)
                Text(model.text(ja: "UI言語 / Language", en: "Language / UI言語"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Picker("", selection: Binding(
                    get: { model.preferences.appLanguage },
                    set: { model.setLanguage($0) }
                )) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.selectionTitle).tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Tab 1: Corners & Layout

    private var cornersAndLayoutTab: some View {
        Form {
            if model.isCompanionAppRunning {
                Section {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "exclamationmark.octagon.fill")
                            .foregroundStyle(.red)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.text(
                                ja: "ChatGPT版の InnerCorners.app が同時に起動しています",
                                en: "ChatGPT Edition (InnerCorners.app) is running concurrently"
                            ))
                            .font(.subheadline.weight(.semibold))
                            Text(model.text(
                                ja: "2つのアプリが同時に壁のイベント監視を行うと、アクションが二重発火して即キャンセルされる原因になります。片方を終了してください。",
                                en: "Running two barrier event taps at the same time can cause duplicate triggers and immediate cancellation. Please quit one of them."
                            ))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(model.text(ja: "ChatGPT版を終了", en: "Quit ChatGPT App")) {
                            model.terminateCompanionApp()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
            }

            if !model.accessibilityGranted {
                Section {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.text(
                                ja: "クイックメモ・通知センター・ロック画面にはアクセシビリティ権限が必要です",
                                en: "Accessibility permission is required for Quick Note, Notification Center, and Lock Screen"
                            ))
                            .font(.subheadline.weight(.semibold))
                            Text(model.text(
                                ja: "壁（バリア）やMission Control・デスクトップ・アプリ表示は現在そのまま動作していますが、キー送信を伴うアクション（クイックメモ／通知センター／ロック画面）を使うには「システム設定 ＞ プライバシーとセキュリティ ＞ アクセシビリティ」で InnerCorners Gemini をオンにしてください。",
                                en: "Barriers, Mission Control, Show Desktop, and Apps work immediately, but key-driven actions (Quick Note, Notification Center, Lock Screen) require enabling InnerCorners Gemini in System Settings > Privacy & Security > Accessibility."
                            ))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(model.text(ja: "権限設定を開く…", en: "Open Settings…")) {
                            model.requestAccessibilityPermission()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            Section(model.text(ja: "画面配置と接合部ソフトバリア（クリックで角を選択）", en: "Display Layout & Junction Barriers (Click a Corner to Select)")) {
                DisplayLayoutView(
                    displays: model.displays,
                    zoneSize: model.preferences.zoneSize,
                    barrierSegments: model.previewBarrierSegments,
                    hoveredZoneID: model.hoveredZoneID,
                    lastHitBarrierID: model.lastHitBarrierID,
                    selectedDisplayID: model.selectedDisplayID,
                    selectedCorner: model.selectedCorner,
                    language: model.language,
                    cornerPolicy: { displayID, corner in
                        model.barrierPolicy(displayID: displayID, corner: corner)
                    },
                    cornerBadge: { displayID, corner in
                        model.shortCornerBadge(displayID: displayID, corner: corner)
                    },
                    onSelectCorner: { displayID, corner in
                        model.selectCorner(displayID: displayID, corner: corner)
                    }
                )
            }

            if let selectedDisplay = model.displays.first(where: { $0.id == model.selectedDisplayID }) ?? model.displays.first {
                selectedCornerInspectorSection(display: selectedDisplay, corner: model.selectedCorner)
            }

            ForEach(model.displays) { display in
                Section(model.text(
                    ja: "\(display.name)（画面 \(display.displayNumber)）の4隅一覧",
                    en: "All 4 Corners for \(display.name) (Display \(display.displayNumber))"
                )) {
                    ForEach(Corner.allCases) { corner in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Button {
                                model.selectCorner(displayID: display.id, corner: corner)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: (model.selectedDisplayID == display.id && model.selectedCorner == corner) ? "smallcircle.filled.circle.fill" : "circle")
                                        .foregroundStyle(Color.accentColor)
                                    Text(model.cornerTitle(corner))
                                        .fontWeight((model.selectedDisplayID == display.id && model.selectedCorner == corner) ? .semibold : .regular)
                                }
                            }
                            .buttonStyle(.plain)
                            .frame(width: 95, alignment: .leading)

                            Picker("", selection: Binding(
                                get: { model.barrierPolicy(displayID: display.id, corner: corner) },
                                set: {
                                    model.selectCorner(displayID: display.id, corner: corner)
                                    model.setBarrierPolicy($0, displayID: display.id, corner: corner)
                                }
                            )) {
                                ForEach(CornerBarrierPolicy.allCases) { policy in
                                    Text(policy.title(language: model.language)).tag(policy)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 175)

                            Picker("", selection: Binding(
                                get: { model.barrierAction(displayID: display.id, corner: corner) },
                                set: {
                                    model.selectCorner(displayID: display.id, corner: corner)
                                    model.setAction($0, displayID: display.id, corner: corner)
                                }
                            )) {
                                ForEach(CornerAction.allCases) { action in
                                    Text(model.actionTitle(action)).tag(action)
                                }
                            }
                            .labelsHidden()
                            .disabled(model.barrierPolicy(displayID: display.id, corner: corner) != .enabled)
                        }
                        Text(model.effectiveActionDescription(displayID: display.id, corner: corner))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func selectedCornerInspectorSection(display: DisplayDescriptor, corner: Corner) -> some View {
        Section(model.text(
            ja: "選択中のコーナー詳細設定：\(display.name)・\(model.cornerTitle(corner))",
            en: "Selected Corner Settings: \(display.name) · \(model.cornerTitle(corner))"
        )) {
            HStack {
                Picker(model.text(ja: "画面", en: "Display"), selection: Binding(
                    get: { display.id },
                    set: { model.selectCorner(displayID: $0, corner: corner) }
                )) {
                    ForEach(model.displays) { item in
                        Text("\(item.name) (#\(item.displayNumber))").tag(item.id)
                    }
                }
                Picker(model.text(ja: "コーナー", en: "Corner"), selection: Binding(
                    get: { corner },
                    set: { model.selectCorner(displayID: display.id, corner: $0) }
                )) {
                    ForEach(Corner.allCases) { item in
                        Text(model.cornerTitle(item)).tag(item)
                    }
                }
            }

            let policy = model.barrierPolicy(displayID: display.id, corner: corner)
            Picker(model.text(ja: "この角の壁の挙動", en: "Barrier Policy"), selection: Binding(
                get: { policy },
                set: { model.setBarrierPolicy($0, displayID: display.id, corner: corner) }
            )) {
                ForEach(CornerBarrierPolicy.allCases) { item in
                    Text(item.title(language: model.language)).tag(item)
                }
            }

            if policy == .enabled {
                let action = model.barrierAction(displayID: display.id, corner: corner)
                Picker(model.text(ja: "実行するアクション", en: "Action"), selection: Binding(
                    get: { action },
                    set: { model.setAction($0, displayID: display.id, corner: corner) }
                )) {
                    ForEach(CornerAction.allCases) { item in
                        Text(model.actionTitle(item)).tag(item)
                    }
                }

                Picker(model.text(ja: "発火に必要な修飾キー", en: "Required Modifier Key"), selection: Binding(
                    get: { model.modifierRequirement(displayID: display.id, corner: corner) },
                    set: { model.setModifierRequirement($0, displayID: display.id, corner: corner) }
                )) {
                    ForEach(CornerModifierRequirement.allCases) { req in
                        Text(req.title(language: model.language)).tag(req)
                    }
                }

                if action == .openApplication {
                    LabeledContent(model.text(ja: "起動するアプリ", en: "Target App")) {
                        HStack {
                            Text(model.customApplicationPath(displayID: display.id, corner: corner) ?? model.text(ja: "未選択", en: "Not selected"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Button(model.text(ja: "アプリを選択…", en: "Choose App…")) {
                                model.chooseCustomApplication(displayID: display.id, corner: corner)
                            }
                        }
                    }
                }

                if action == .runShortcut {
                    LabeledContent(model.text(ja: "ショートカット名", en: "Shortcut Name")) {
                        TextField(
                            model.text(ja: "ショートカット.appのワークフロー名", en: "Workflow name in Shortcuts.app"),
                            text: Binding(
                                get: { model.customShortcutName(displayID: display.id, corner: corner) ?? "" },
                                set: { model.setCustomShortcutName($0, displayID: display.id, corner: corner) }
                            )
                        )
                        .textFieldStyle(.roundedBorder)
                    }
                }
            }

            Text(model.effectiveActionDescription(displayID: display.id, corner: corner))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Tab 2: Barrier & Behavior

    private var barrierAndBehaviorTab: some View {
        Form {
            Section(model.text(ja: "接合部ソフトバリア", en: "Junction Barrier")) {
                Toggle(
                    model.text(ja: "内側角に一方向の壁を作る", en: "Block passage through inner corners"),
                    isOn: $model.preferences.barrierEnabled
                )
                LabeledContent(model.text(ja: "壁の長さ", en: "Barrier Length")) {
                    HStack {
                        Slider(value: $model.preferences.barrierLength, in: 10...100, step: 1)
                        Text("\(Int(model.preferences.barrierLength)) pt").monospacedDigit().frame(width: 55)
                    }
                }
                Picker(
                    model.text(ja: "壁の遮断モード", en: "Barrier Mode"),
                    selection: $model.preferences.passThroughMode
                ) {
                    ForEach(BarrierPassThroughMode.allCases) { mode in
                        Text(mode.title(language: model.language)).tag(mode)
                    }
                }
                if model.preferences.passThroughMode == .speedBump {
                    LabeledContent(model.text(ja: "押し込み通過時間", en: "Push-Through Hold Time")) {
                        HStack {
                            Slider(value: $model.preferences.speedBumpHoldMilliseconds, in: 150...800, step: 25)
                            Text("\(Int(model.preferences.speedBumpHoldMilliseconds)) ms")
                                .monospacedDigit()
                                .frame(width: 65)
                        }
                    }
                    Text(model.text(
                        ja: "スピードバンプモードでは、最初の衝突でカーソルが止まって角の操作やホットコーナー発火を行い、そのまま指定時間押し続けるとOptionキーなしで隣画面へ通過できます。",
                        en: "In Speed Bump mode, the initial collision stops the pointer at the corner; continuing to push against the corner for the hold time lets the pointer pass through without holding Option."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    Text(model.text(
                        ja: "常時遮断モードでは、壁が有効な内部コーナーはOptionキーを押さない限り通過できません。画面内側へ離れて同じ角へ再衝突するとMission Control等をキャンセルできます。",
                        en: "In Always Block mode, inner corners remain impassable unless Option is held. Move inward and hit the same corner again to cancel Mission Control or a similar action."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Text(model.barrierStatus)
            }

            Section(model.text(ja: "一時停止・フルスクリーン・除外アプリ", en: "Temporary Pause, Fullscreen & Excluded Apps")) {
                HStack {
                    if model.isTemporarilyPaused {
                        Button(model.text(ja: "一時停止を今すぐ解除", en: "Resume Now")) {
                            model.resumeFromTemporaryPause()
                        }
                        if let deadline = model.pausedUntil {
                            Text(model.text(
                                ja: "（\(DateFormatter.localizedString(from: deadline, dateStyle: .none, timeStyle: .short)) まで一時停止中）",
                                en: "(Paused until \(DateFormatter.localizedString(from: deadline, dateStyle: .none, timeStyle: .short)))"
                            ))
                            .font(.caption)
                            .foregroundStyle(.orange)
                        }
                    } else {
                        Button(model.text(ja: "5分間バリアとアクションを一時停止", en: "Pause Barriers & Actions for 5 Minutes")) {
                            model.pauseForMinutes(5)
                        }
                    }
                }

                Toggle(
                    model.text(
                        ja: "フルスクリーンアプリが最前面のときは自動抑制する",
                        en: "Automatically suppress while a fullscreen app is frontmost"
                    ),
                    isOn: $model.preferences.pauseInFullscreenApps
                )

                Picker(
                    model.text(ja: "フルスクリーン・除外アプリ時の抑制範囲", en: "Suppression Scope"),
                    selection: $model.preferences.suppressionScope
                ) {
                    ForEach(SuppressionScope.allCases) { scope in
                        Text(scope.title(language: model.language)).tag(scope)
                    }
                }

                LabeledContent(model.text(ja: "現在の前面アプリ", en: "Current Frontmost App")) {
                    HStack {
                        Text("\(model.frontmostApplicationName) (\(model.frontmostApplicationBundleID ?? "-"))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button(
                            model.isFrontmostAppExcluded
                                ? model.text(ja: "除外を解除", en: "Remove Exclusion")
                                : model.text(ja: "除外に追加", en: "Exclude Frontmost")
                        ) {
                            model.toggleFrontmostAppExclusion()
                        }
                        .disabled(model.frontmostApplicationBundleID == nil)
                        Button(model.text(ja: "アプリを選択して追加…", en: "Add App…")) {
                            model.chooseExcludedApplication()
                        }
                    }
                }

                if model.preferences.excludedBundleIdentifiers.isEmpty {
                    Text(model.text(ja: "除外アプリは登録されていません", en: "No excluded applications"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.preferences.excludedBundleIdentifiers, id: \.self) { bundleID in
                        HStack {
                            Text(bundleID)
                                .font(.caption.monospaced())
                            Spacer()
                            Button(model.text(ja: "削除", en: "Remove")) {
                                model.removeExcludedBundleIdentifier(bundleID)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }

            Section(model.text(ja: "独自の領域アクション（補助機能）", en: "Custom Activation Zones (Auxiliary)")) {
                Toggle(
                    model.text(ja: "独自の領域アクションを有効にする", en: "Enable custom activation zones"),
                    isOn: $model.preferences.isEnabled
                )
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
                Text(model.text(
                    ja: "接合部バリアが有効な内部コーナーでは壁衝突時にアクションが発火し、独自の領域アクションとの二重発火は自動的に防止されます。",
                    en: "At inner corners where a junction barrier is active, actions fire on barrier collision and duplicate zone triggers are automatically suppressed."
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Tab 3: Safety & Diagnostics

    private var safetyAndDiagnosticsTab: some View {
        Form {
            Section(model.text(ja: "権限と安全機構", en: "Permissions & Safety")) {
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
                HStack {
                    Button(model.text(ja: "アクセシビリティ権限を開く…", en: "Open Accessibility Settings…")) {
                        model.requestAccessibilityPermission()
                    }
                    Button(model.text(ja: "テスト音を鳴らす（権限不要）", en: "Play Test Sound (No Permission Required)")) {
                        model.runTestSound()
                    }
                }
                LabeledContent(model.text(ja: "キーボード緊急終了", en: "Keyboard Emergency Quit"), value: model.emergencyHotKeyStatus)
                Text(model.text(
                    ja: "緊急解除：Optionキーを押しながら動かすと一時的に通過できます。⌃⌥⌘Qは壁をオフとして保存してからアプリを終了します。",
                    en: "Emergency bypass: hold Option while moving to pass through temporarily. ⌃⌥⌘Q saves the barrier as off, then quits the app."
                )).font(.caption).foregroundStyle(.orange)
            }

            Section(model.text(ja: "ライブ状態", en: "Live Status")) {
                Text(model.status)
                LabeledContent(model.text(ja: "現在のポインタ判定", en: "Current Pointer Detection"), value: model.pointerStatus)
                LabeledContent(
                    model.text(ja: "前面アプリ", en: "Frontmost App"),
                    value: "\(model.frontmostApplicationName)\(model.isFrontmostAppFullscreen ? model.text(ja: "（フルスクリーン）", en: " (Fullscreen)") : "")"
                )
            }

            Section(model.text(ja: "診断と履歴", en: "Diagnostics & History")) {
                LabeledContent(model.text(ja: "バージョン", en: "Version"), value: model.versionDescription)
                LabeledContent(model.text(ja: "認識画面", en: "Detected Displays"), value: model.text(ja: "\(model.displays.count)台", en: "\(model.displays.count)"))
                LabeledContent(model.text(ja: "有効な方向別の壁", en: "Active Directional Barriers"), value: model.text(ja: "\(model.barrierCount)本", en: "\(model.barrierCount)"))
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
            }
        }
        .formStyle(.grouped)
    }
}
