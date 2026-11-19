# Gemini統合進捗

更新日: 2026-11-19 17:03 JST
作業ブランチ: `codex/gemini-integration`  
安定比較基準: `main` / `v0.11.0-rc.7`

## 現在の位置

Gemini Edition v0.12.0（Info.plist build 64）を専用ブランチへ取り込み、Phase Bの主要な安全修正を先行している。`main`の製品コードはRC7系のままで、統合版はまだ日常利用版・配布候補ではない。

## 完了した変更

1. `f3b8882` — Gemini基準ソースを統合ブランチへ取込み。
   - RC7系で訂正済みのASM下端座標fixtureを適用。
2. `3f0f509` — RC7系アプリとの同時起動中は、壁とアクションを起動しない。
3. `a84c010` — InnerCorners自身が前面のとき、Application Windowsを抑制。
4. `215260a` — Accessibility APIとキーボードイベント送信権限を個別判定・個別表示。
5. `8eb83bc` — イベントタップ復旧前に現在のカーソル位置へ再同期。
6. `668df52` — 一時停止・除外・競合停止中も、スリープ／画面変更後の安全ゲートを保持。
7. `061cdd7` — Quartz画面情報の取得失敗中は古いgeometryから壁を再開しない。
8. `56f930c` — スピードバンプ通過直後の逆方向衝突を即時再ロック。
9. `6a23c59` — 壁衝突時の修飾キー状態を保存し、非同期実行時の読み直しを防止。
10. `1616df5` — アプリ起動・システムコマンドの非同期完了結果を履歴へ記録。
11. `f16798e` — 一時停止・除外・フルスクリーン抑制の安全状態保持を組合せ試験。

## 自動検証

- `swift test --disable-sandbox`: 79件すべて合格。
- `Scripts/run_self_tests.sh`: 合格。
- Swift 6 release build（`-warnings-as-errors`）: 合格。
- `Scripts/build_app.sh`: 合格。
- アドホック署名検証: 合格。
- ZIP再展開後の署名検証: 合格。
- 生成ZIP SHA-256: `194fdb89119825956e725faeb2ab5c8057c634f50eb5a09f23bc2186d15f828f`

生成物: `outputs/InnerCorners-GE-v0.12.0-build66-arm64.app.zip`（Git管理外）

## build 66 実機安全試験

製品名を`InnerCorners GE`、Bundle IDを`local.prototype.InnerCorners.GE`へ確定し、build 66として`/Applications/InnerCorners GE.app`へ配置した。旧build 65は`/Applications/InnerCorners GE build65 backup.app`へ退避してあり、削除していない。

- macOSアクセシビリティ再許可後、Quartzイベントタップが1本・`enabled=true`になったことをOS側から確認。
- GE単独待機時の観測CPU使用率は0.0%。
- RC7を併起動すると、GE自身のイベントタップが1本から0本へ停止し、RC7側だけが1本を保持。
- RC7終了後、GEのイベントタップが0本から1本へ自動復帰。
- `⌃⌥⌘Q`をCGEventで送信すると、GEが終了。OSログにも緊急終了を記録。
- 非常終了が保存した`barrierEnabled=false`を、他設定を維持したまま`true`へ復元して再起動。イベントタップ1本への復帰を確認。

上記はプロセス、Quartzイベントタップ一覧、OSログで確認した実機結果。実際のコーナー衝突と発火は、カーソル自動ワープの危険を避けるため手動確認待ち。

## 未検証・未完了

- 統合版アプリの実際のコーナー衝突とアクション発火。
- スリープ／復帰、画面切断／再接続、解像度・配置変更。
- 一時停止、アプリ除外、フルスクリーン抑制と安全待機の組合せ。
- WindowServerによるイベントタップタイムアウトからの実復旧。
- スピードバンプ直後の逆方向再衝突の実機確認（自動テストは追加済み）。
- 追加アクションの実環境での非同期完了診断（記録経路と自動テストは追加済み）。
- READMEと版表記を`v0.12.0-beta.1`へ整える作業（製品名はInnerCorners GEへ改名済み）。

## 次の順序

1. 安全状態遷移の不足テストを追加する。
2. スピードバンプの再ロック条件を修正・検証する。
3. 統合版をRC7系と同時起動せず、限定実機試験する。
4. 実機合格後にREADMEと版番号をbeta向けへ更新する。
5. `main`へはまだ統合しない。
