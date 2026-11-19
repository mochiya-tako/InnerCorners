# Gemini Edition v0.12.0 基準ソース監査

確認日: 2026-11-19  
比較基準: Git tag `v0.11.0-rc.7`（build 54）  
対象: `InnerCorners-Gemini-v0.12.0-source(2).zip`

## 1. ソースの固定情報

- SHA-256: `f55348c8a43531a7be8d29fe0dd697b9253b88437a9144087450c47482795085`
- アーカイブ内ルート: `InnerCorners-Gemini-v0.12.0-source/`
- `Packaging/Info.plist`: version `0.12.0`, build `64`
- `README.md`: `Gemini Edition v0.12.0 (build 60)`
- 結論: READMEと実際のInfo.plistのbuild番号は不一致。
- 絶対パスおよび`..`を含むアーカイブ項目は検出されなかった。

この文書はハッシュと比較結果を記録する。元ZIPは一時添付キャッシュにあり、リポジトリには収録しない。

## 2. 再現した規模

| 項目 | RC7 | Gemini版 |
|---|---:|---:|
| 製品Swiftファイル | 19 | 21 |
| 製品Swift行数 | 2,724 | 4,304 |
| テストSwiftファイル | 10 | 12 |
| XCTestメソッド | 60 | 70 |

製品ソース差分は1,822行追加、242行削除。既存11ファイルが変更され、既存8ファイルはバイト単位で同一、2ファイルが追加されている。

### RC7とバイト単位で同一の8ファイル

- `ActivationGate.swift`
- `ActivationSafetyGate.swift`
- `BarrierSafetyGate.swift`
- `CollisionReactivationGate.swift`
- `DisplayProvider.swift`
- `EmergencyHotKeyController.swift`
- `SystemHotCornerAction.swift`
- `SystemHotCornerModifier.swift`

### Gemini版で追加された2ファイル

- `AppSuppressionPolicy.swift`
- `SpeedBumpGate.swift`

### Gemini版で変更された既存11ファイル

- `ActionExecutor.swift`
- `AppModel.swift`
- `CursorBarrierController.swift`
- `CursorBarrierGeometry.swift`
- `DisplayLayoutView.swift`
- `Geometry.swift`
- `HotCornerEngine.swift`
- `InnerCornersApp.swift`
- `Localization.swift`
- `Models.swift`
- `SettingsView.swift`

## 3. Xcode 27.2での自動テスト

作業用キャッシュを`/private/tmp`へ限定し、SwiftPMの入れ子サンドボックスを無効にして`swift test`を実行した。

- コンパイル: 成功
- 実行: 70件
- 成功: 69件
- 失敗: 1件

失敗したのは`testExactBottomRightArrivalCountsAsContactWithoutSeamCrossing`。Gemini版のテストはASM画面の下端を`y = 1080`としているが、当該fixtureのASM frameは`y = -119 ... 961`である。現在のRC7系では到達点を`(0, 961)`、拘束点を`(-0.5, 960.5)`へ訂正済みで、60件すべて合格している。

したがって、この1件は現時点ではGemini製品コードの失敗とは判定しない。統合ブランチではRC7系の訂正済みfixtureを適用してから再実行する。

## 4. 静的レビュー指摘の再分類

### 確認済み

1. **同時起動検出が壁の開始を阻止しない**
   - `refreshCompanionAppStatus()`は状態表示を更新するだけで、イベントタップ開始の事前条件になっていない。
   - 旧版の検出中もGemini版がカーソル制御を開始し得る。
2. **Application Windowsの自己前面ガードが削除されている**
   - RC7にあった「InnerCorners自身が前面なら抑制」がGemini版の直接アクション経路から削除されている。
3. **権限判定が論理和へ弱められている**
   - `isAccessibilityGranted`およびキーボードイベント送信前判定が`AXIsProcessTrusted() || CGPreflightPostEventAccess()`になっている。
   - 異なる用途の権限を個別診断できない。
4. **イベントタップ復旧時にカーソル状態を再同期しない**
   - タイムアウト復旧は`CGEvent.tapEnable`と状態表示だけで、`previousLocation`等を現在位置へ同期しない。
5. **READMEとInfo.plistのbuild番号が不一致**
   - READMEは60、Info.plistは64。
6. **RC7で訂正済みの誤った座標fixtureが残っている**
   - これによりXcode 27.2で70件中1件が失敗する。

### 一部反証・要件の絞り込み

1. **抑制経路が常に安全ゲートを消去する、という一般化**
   - Gemini版には`stop(preservingSafetyState: true)`があり、画面通知処理の複数経路では安全状態を保持している。
   - ただし通常の`stop()`は安全ゲートをリセットするため、一時停止・除外・フルスクリーン抑制を含む全呼出経路の状態遷移テストが必要。問題なしとはまだ判定できない。
2. **安全ゲート8ファイル自体が改変されている可能性**
   - 上記8ファイルはRC7とバイト単位で同一だったため、この可能性は反証された。
   - リスクは主に呼出側と追加状態の統合方法にある。

### 追加検証が必要

- 画面構成取得失敗中に古いgeometryが再開されるか。
- 一時停止、除外、フルスクリーン抑制とスリープ／画面変更安全待機の全組合せ。
- スピードバンプ通過直後の逆方向再衝突。
- 修飾キーのサンプリング時点と衝突イベントの一致。
- 非同期アプリ／ショートカット実行の完了結果。
- 実機での高頻度入力、スリープ復帰、画面切断・再接続。

## 5. Phase A時点の判断

Gemini版を次期開発ベースにする方針は維持できる。ただし、現物はそのまま`main`へ置ける状態ではない。統合ブランチでは最初に、訂正済みテストfixture、同時起動時の開始阻止、Application Windows自己前面ガード、権限の個別判定、イベントタップ復旧時の座標同期を適用・テストする。

実機動作はこの監査では未確認。現段階の表現は「ソース固定・静的比較・macOS上のコンパイル確認済み、70テスト中69件成功」である。
