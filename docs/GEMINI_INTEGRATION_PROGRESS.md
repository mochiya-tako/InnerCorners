# Gemini統合進捗

更新日: 2026-11-19 18:19 JST
作業ブランチ: `codex/gemini-integration`  
安定比較基準: `main` / `v0.11.0-rc.7`

## 現在の位置

Gemini Edition v0.12.0を専用ブランチへ取り込み、Phase Bの主要な安全修正と限定実機試験を進めている。現在の統合版は`InnerCorners GE` build 70。`main`の製品コードはRC7系のままで、統合版はまだ正式な日常利用版・配布候補ではない。

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
12. `bcb173e` — 画面収録権限に依存せず、別コーナー衝突によるワークスペース表示のキャンセル候補を追跡。
13. `9e6dc07` — 別コーナーでのキャンセル時にEscapeを先行送信せず、直前に開いたMission Control系機能を再度呼ぶ方式へ変更。Appsの非同期表示とEscapeが前後して検索画面だけ残る競合を解消。
14. build 70 — Apps／Launchpad／Mission Control／Dock自身のアプリ切替通知ではキャンセル待機を消さず、通常アプリへの切替とクリックでは消すよう通知境界を修正。

## 自動検証

- `swift test`: 88件すべて合格。
- `Scripts/run_self_tests.sh`: 合格。
- Swift 6 release build（`-warnings-as-errors`）: 合格。
- `Scripts/build_app.sh`: 合格。
- アドホック署名検証: 合格。
- ZIP再展開後の署名検証: 合格。
- 生成ZIP SHA-256: `821df0995a47a9074cac2da927723c9f628ea255f0c35b459277a1ffead7c867`

生成物: `outputs/InnerCorners-GE-v0.12.0-build70-arm64.app.zip`（Git管理外）

## build 66 実機安全試験

製品名を`InnerCorners GE`、Bundle IDを`local.prototype.InnerCorners.GE`へ確定し、build 66として`/Applications/InnerCorners GE.app`へ配置した。旧build 65は`/Applications/InnerCorners GE build65 backup.app`へ退避してあり、削除していない。

- macOSアクセシビリティ再許可後、Quartzイベントタップが1本・`enabled=true`になったことをOS側から確認。
- GE単独待機時の観測CPU使用率は0.0%。
- RC7を併起動すると、GE自身のイベントタップが1本から0本へ停止し、RC7側だけが1本を保持。
- RC7終了後、GEのイベントタップが0本から1本へ自動復帰。
- `⌃⌥⌘Q`をCGEventで送信すると、GEが終了。OSログにも緊急終了を記録。
- 非常終了が保存した`barrierEnabled=false`を、他設定を維持したまま`true`へ復元して再起動。イベントタップ1本への復帰を確認。
- ユーザー実機確認: 内部コーナーの低速・高速衝突、壁停止とアクション発火、再衝突キャンセル、Option緊急通過はいずれも異常なし。

自動確認部分はプロセス、Quartzイベントタップ一覧、OSログで確認した。カーソル操作を伴う項目はユーザーが実機で確認した。

## builds 67–69 ワークスペース表示キャンセル試験

- Mission Control、Application Windows、Show Desktop、Appsのうち、ある機能の表示中に別コーナーへ衝突した場合も、次の機能を重ねて起動せず直前の表示をキャンセルする状態管理を追加。
- 画面収録権限がない通常構成ではWindowServerのウインドウ名を取得できないことを実機で確認。追加権限を要求せず、アプリ自身が直前の発火対象を最大30秒保持する方式を採用。
- build 68の高速なApps→Show Desktop操作で、Appsの非同期表示よりEscapeが先行し、遅れてApps検索画面だけが現れる競合を実機で確認。
- build 69では直前の機能自体を再度呼ぶトグル方式へ変更。ユーザーが右下Apps→左上Show Desktopを含む高速な連続操作を実機確認し、異常なし。
- build 69起動後、Quartzイベントタップが1本・`enabled=true`であること、およびOSログでApps後のShow Desktop衝突が`workspace-cancel-requested`として処理されたことを確認。
- Escape送信は、画面状態を直接検出できたが直前対象を保持していない予備経路だけに限定し、修飾キーフラグを明示的に空にした。

## build 70 Apps起動通知の回帰試験

- build 69の組合せ試験ログで、高速なApps→別コーナーはキャンセルされる一方、Apps表示後に約3秒置いた操作ではApps自身のアプリ切替通知が待機状態を消すことを確認。
- `com.apple.apps.launcher`、旧OS用`com.apple.launchpad.launcher`、`com.apple.exposelauncher`、`com.apple.dock`だけを待機解除の例外とした。通常アプリへの切替と識別不能な通知は安全側で解除する。
- ユーザー実機試験で、Apps完全表示から約5秒後のShow Desktop衝突がキャンセルとして処理されることを確認。
- 続く高速試験では、Appsから約1.1〜1.4秒後のShow Desktop衝突を複数回キャンセルとして記録。意図しないApps／Spotlight表示の残留はユーザーから報告されなかった。
- Mission Control、Application Windows、Show Desktop、Appsについて、同一機能への再衝突と異なる機能間の全方向を実機操作とOSログで確認。いずれも次の機能を重ねて起動せず`workspace-cancel-requested`として処理された。
- build 70起動後のQuartzイベントタップは1本・`enabled=true`。
- build 70を`pmset sleepnow`で実スリープさせ、同一PIDで復帰。復帰直後は壁を停止した安全確認状態を維持し、5秒以上経過後にカーソルを画面中央へ移すと壁を再開した。再開後もイベントタップ1本・`enabled=true`で、復帰中の誤発火は記録されなかった。
- 3画面をL字配置へ変更する過程の複数通知すべてで安全待機へ入り、各回5秒以上経過後に壁を再開。変更後は画面1・2・3それぞれの内部コーナーを実機操作し、ログ上の進入元と対象画面が一致した。別画面の同座標角への取り違え、誤発火、クラッシュは記録されなかった。

## 未検証・未完了

- build 69でのスリープ／復帰、画面切断／再接続、解像度・配置変更の再回帰。
- 一時停止、アプリ除外、フルスクリーン抑制と安全待機の組合せ。
- WindowServerによるイベントタップタイムアウトからの実復旧。
- スピードバンプ直後の逆方向再衝突の実機確認（自動テストは追加済み）。
- 追加アクションの実環境での非同期完了診断（記録経路と自動テストは追加済み）。
- Apps起動要求直後の極端に短い間隔を含む、全ワークスペース機能間の相互キャンセル組合せ試験。
- READMEと版表記を`v0.12.0-beta.1`へ整える作業（製品名はInnerCorners GEへ改名済み）。

## 次の順序

1. build 69でワークスペース4機能の相互キャンセルを組合せ確認する。
2. スリープ／復帰、画面構成変更、一時停止・除外・フルスクリーン抑制を再回帰する。
3. WindowServerイベントタップタイムアウトからの実復旧を可能な範囲で確認する。
4. 実機合格後にREADMEと版番号をbeta向けへ更新する。
5. `main`へはまだ統合しない。
