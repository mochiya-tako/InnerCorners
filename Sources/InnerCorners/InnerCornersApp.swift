import AppKit
import ApplicationServices
import SwiftUI

final class LaunchDelegate: NSObject, NSApplicationDelegate {
    private var duplicateInstance = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = icon
        }
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let currentPID = ProcessInfo.processInfo.processIdentifier
        guard let existing = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .first(where: { $0.processIdentifier != currentPID && !$0.isTerminated }) else { return }

        duplicateInstance = true
        existing.activate(options: [.activateAllWindows])
        if ProcessInfo.processInfo.environment["INNERCORNERS_DIAGNOSTICS"] == "1" {
            FileHandle.standardError.write(Data("InnerCorners is already running; terminating duplicate instance.\n".utf8))
        }
        DispatchQueue.main.async {
            NSApplication.shared.terminate(nil)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !duplicateInstance else { return }
        guard CommandLine.arguments.contains("--request-accessibility") else { return }
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }
}

@main
struct InnerCornersApp: App {
    @NSApplicationDelegateAdaptor(LaunchDelegate.self) private var launchDelegate
    @StateObject private var model = AppModel()

    private var menuBarIcon: NSImage {
        let icon = Bundle.main.url(forResource: "MenuBarIcon@2x", withExtension: "png")
            .flatMap(NSImage.init(contentsOf:))
            ?? NSImage(systemSymbolName: "cursorarrow.rays", accessibilityDescription: "InnerCorners")
            ?? NSImage(size: NSSize(width: 18, height: 18))
        icon.size = NSSize(width: 18, height: 18)
        icon.isTemplate = false
        return icon
    }

    var body: some Scene {
        MenuBarExtra {
            Toggle(model.text(ja: "接合部の壁", en: "Junction Barrier"), isOn: $model.preferences.barrierEnabled)
            Toggle(model.text(ja: "独自の領域アクション", en: "Custom Zone Actions"), isOn: $model.preferences.isEnabled)
            Text(model.barrierStatus)
            Text(model.emergencyHotKeyStatus)
            Text(model.status)
            Divider()
            SettingsLink { Text(model.text(ja: "設定…", en: "Settings…")) }
            Divider()
            Button(model.text(ja: "終了", en: "Quit")) { NSApplication.shared.terminate(nil) }
        } label: {
            Image(nsImage: menuBarIcon)
                .accessibilityLabel("InnerCorners")
        }
        .menuBarExtraStyle(.menu)
        .environment(\.locale, Locale(identifier: model.language.localeIdentifier))

        Settings {
            SettingsView(model: model)
        }
    }
}
