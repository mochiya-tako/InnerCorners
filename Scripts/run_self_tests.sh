#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
TEST_BUILD_DIR="${TMPDIR%/}/InnerCorners-GE-self-tests"
rm -rf "$TEST_BUILD_DIR"
mkdir -p "$TEST_BUILD_DIR"

cat > "$TEST_BUILD_DIR/TestMain.swift" << 'EOF'
import CoreGraphics
import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String = "Assertion failed", file: String = #file, line: Int = #line) {
    if !condition() {
        FileHandle.standardError.write(Data("FAIL [\(file):\(line)]: \(message)\n".utf8))
        exit(1)
    }
}

@main
struct SelfTestRunner {
    static func main() throws {
        // 1. SpeedBumpGate tests
        let ownerFrame = CGRect(x: 0, y: 0, width: 2560, height: 1080)
        let barrier = CursorBarrier(
            id: "1:topLeft:left",
            displayID: 1,
            corner: .topLeft,
            axis: .vertical,
            coordinate: 0,
            span: -40...40,
            ownerSide: .higherCoordinate,
            ownerFrame: ownerFrame
        )
        var speedBump = SpeedBumpGate()
        check(speedBump.evaluateCollision(barrier: barrier, now: 10.0, mode: .alwaysBlock, holdDuration: 0.3) == .block)
        check(speedBump.evaluateCollision(barrier: barrier, now: 10.4, mode: .alwaysBlock, holdDuration: 0.3) == .block)

        check(speedBump.evaluateCollision(barrier: barrier, now: 20.00, mode: .speedBump, holdDuration: 0.30) == .block)
        check(speedBump.evaluateCollision(barrier: barrier, now: 20.15, mode: .speedBump, holdDuration: 0.30) == .block)
        check(speedBump.evaluateCollision(barrier: barrier, now: 20.31, mode: .speedBump, holdDuration: 0.30) == .allowPassage)
        speedBump.observeNonCollidingMovement(at: CGPoint(x: 50, y: 50), now: 20.50)
        check(speedBump.evaluateCollision(barrier: barrier, now: 20.60, mode: .speedBump, holdDuration: 0.30) == .block)

        // 2. AppSuppressionPolicy tests
        let now = Date(timeIntervalSince1970: 1_000)
        var prefs = Preferences()
        prefs.excludedBundleIdentifiers = ["com.valvesoftware.steam"]
        prefs.suppressionScope = .actionsOnly
        let state1 = AppSuppressionPolicy.evaluate(
            now: now,
            pausedUntil: nil,
            frontmostBundleID: "com.valvesoftware.steam",
            isFrontmostFullscreen: false,
            preferences: prefs
        )
        check(state1.shouldSuppressActions && !state1.shouldSuppressBarriers)
        prefs.suppressionScope = .barriersAndActions
        let state2 = AppSuppressionPolicy.evaluate(
            now: now,
            pausedUntil: nil,
            frontmostBundleID: "com.valvesoftware.steam",
            isFrontmostFullscreen: false,
            preferences: prefs
        )
        check(state2.shouldSuppressActions && state2.shouldSuppressBarriers)

        // 3. Per-corner disabled barrier & preview segments tests
        let lg = QuartzDisplayDescriptor(id: 1, name: "LG", frame: CGRect(x: 0, y: 0, width: 2560, height: 1080))
        let asm = QuartzDisplayDescriptor(id: 3, name: "ASM", frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080))
        let allBarriers = CursorBarrierGeometry.barriers(for: [lg, asm], length: 40)
        check(allBarriers.count == 4)
        let filteredBarriers = CursorBarrierGeometry.barriers(for: [lg, asm], length: 40, disabledCornerKeys: ["1:bottomLeft"])
        check(filteredBarriers.count == 3)

        // 4. Preferences JSON round-trip & backward compatibility
        let legacyData = Data(#"{"isEnabled":false,"barrierEnabled":true,"barrierLength":40,"assignments":[{"displayID":"d1","corner":"topLeft","action":"missionControl"}]}"#.utf8)
        let decodedLegacy = try JSONDecoder().decode(Preferences.self, from: legacyData)
        check(decodedLegacy.barrierPolicy(displayID: "d1", corner: .topLeft) == .enabled)
        check(decodedLegacy.modifierRequirement(displayID: "d1", corner: .topLeft) == .none)
        check(decodedLegacy.action(displayID: "d1", corner: .topLeft) == .missionControl)

        var customPrefs = Preferences()
        customPrefs.setBarrierPolicy(.stopperOnly, displayID: "d1", corner: .topLeft)
        customPrefs.setModifierRequirement(.controlCommand, displayID: "d1", corner: .topRight)
        customPrefs.setAction(.screenshotSelection, displayID: "d1", corner: .topRight)
        let encodedCustom = try JSONEncoder().encode(customPrefs)
        let roundTripped = try JSONDecoder().decode(Preferences.self, from: encodedCustom)
        check(roundTripped.barrierPolicy(displayID: "d1", corner: .topLeft) == .stopperOnly)
        check(roundTripped.modifierRequirement(displayID: "d1", corner: .topRight) == .controlCommand)
        check(roundTripped.action(displayID: "d1", corner: .topRight) == .screenshotSelection)

        print("All InnerCorners GE self-tests passed!")
    }
}
EOF

SOURCES=(${PROJECT_DIR}/Sources/InnerCorners/*.swift)
SOURCES=(${SOURCES:#*/InnerCornersApp.swift})

CLANG_MODULE_CACHE_PATH="$TEST_BUILD_DIR/clang-cache" swiftc \
  -swift-version 6 \
  -warnings-as-errors \
  -parse-as-library \
  -target arm64-apple-macosx14.0 \
  "${SOURCES[@]}" \
  "$TEST_BUILD_DIR/TestMain.swift" \
  -o "$TEST_BUILD_DIR/run_tests"

"$TEST_BUILD_DIR/run_tests"
