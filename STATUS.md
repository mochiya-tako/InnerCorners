# InnerCorners 現在の開発状況

基準日: 2026-11-19（JST）

## 1. 現在地

| 項目 | 状況 |
| --- | --- |
| バージョン | v0.11.0 RC7 |
| build | 54 |
| ブランチ | `main` |
| ソース状態 | Git管理、GitHub非公開リポジトリと同期 |
| リポジトリ | `mochiya-tako/InnerCorners` |
| 最低対象 | macOS 14 |
| 現行配布CPU | Apple Silicon（arm64） |
| 署名 | アドホック署名 |
| 公証 | 未実施 |
| 公開区分 | プレリリース／個人試用段階 |

最新版アプリはGitHub Releasesの[`v0.11.0-rc.7`](https://github.com/mochiya-tako/InnerCorners/releases/tag/v0.11.0-rc.7)に置かれている。リポジトリが非公開の間は、権限のあるGitHubアカウントだけが取得できる。

## 2. 実装済み

- 各ディスプレイ・各4隅の独立認識と設定保存。
- 10〜100 ptの方向別ソフトバリア。
- 厳密角、高速進入、複数角が同一座標へ集まる配置の所有判定。
- 常時壁、Option一時通過、Control–Option–Command–Q緊急終了。
- 発火後のラッチと、角から離れた後の再衝突によるキャンセル。
- 0〜500 ms滞留の独自矩形領域と、壁経路との二重発火防止。
- 画面接続・切断、配置、解像度、ミラーリング、スリープ復帰への追従。
- 日本語／英語UI。
- ディスプレイ・角ごとのアクション設定。
- Mission Control、Application Windows、Show Desktop、Apps／Launchpad、クイックメモ、通知センター、画面ロック、スクリーンセーバ開始、ディスプレイスリープ。
- 外周の標準設定をmacOSへ委譲し、二重トグルを回避。
- プライバシーを抑えた統合ログとGUI診断表示。
- 重複起動防止、Dock／Command–Tab表示、通常のCommand–Q終了。
- アプリZIPと公開用ソースZIPの生成スクリプト。
- 日英READMEと直接ダウンロードリンク。

## 3. 確認済み範囲

### 実機

- Apple Silicon Mac mini M4。
- macOS 27.0.1。
- 2画面および3画面。
- 横一列、縦一列、L字、凸型、T字、物理ミラーリング。
- 低速・高速・厳密角への衝突。
- 画面切断、再接続、解像度・配置変更。
- 通常のスリープ／復帰。
- Option通過、緊急終了、通常終了。
- 上記の選択可能アクションと、主要な再衝突キャンセル。
- 物理US配列キーボードでクイックメモと通知センター。

### 自動・静的検査

- 幾何計算、所有判定、ラッチ、安全ゲート、設定、Dock値、修飾キー、アクション結果の単体テストを収録。
- Swift 6の警告をエラーとして扱うコンパイル検査に合格した履歴あり。
- 配布ZIPの展開、アプリ版番号、アドホック署名の検証済み成果物をRC7として保存。
- 2026-11-19、Command Line Toolsを27.2としてクリーン再導入。Swift 6.4.2とmacOS SDK 27.2で、`swift build -c release`および`Scripts/build_app.sh`が成功し、アプリ本体、アドホック署名、ZIP再展開後の署名を確認した。
- `swift test`はマニフェスト読込みと本体ビルドを通過したが、Command Line Tools単体に`XCTest`が含まれないためテストターゲットで停止した。コードのテスト失敗ではなく、全単体テストには完全版XcodeまたはSwift Testingへの移行が必要な状態である。

実機確認は記録した構成での事実であり、すべてのMacや周辺機器に対する保証ではない。

## 4. 現在の既知制限

- 長時間のCPU・メモリ測定は未実施。
- 1000 Hz級マウスの持続衝突負荷は未実施。
- Sidecarは未検証。
- macOS 14、15、26は現行機と同等の実機試験をしていない。
- 別Macでの新規インストール試験は未実施。
- Developer ID署名と公証は未実施。
- Option付きホットコーナー割当は安全上の理由で非対応。
- スクリーンセーバ無効化は未実装。
- アプリ自身によるログイン項目登録は行わない。次回ログインからの起動試験も現行RCでは未確認。

## 5. 開発・配布上の状態

- GitHubリポジトリは非公開である。
- RC7アプリはプレリリースとしてダウンロード可能である。
- 現行ZIPはアドホック署名であり、一般利用者向けの公証済み配布物ではない。
- App Store公開は予定せず、将来公開する場合もGitHub Releasesを主経路とする方針である。
- ソースアーカイブは`Scripts/build_source_archive.sh`、アプリは`Scripts/build_app.sh`から生成する。

## 6. 次に行うこと

通常使用によるバグ取りを優先する。問題が見つからない期間に、次を順次進める。

1. 完全版Xcodeを導入するか、テストをSwift Testingへ移行し、全単体テストを再実行する。リリースビルドはCommand Line Tools 27.2で合格済み。
2. 長時間常駐時のCPU・メモリと、イベントタップ停止の有無を記録する。
3. 1000 Hz級マウス、Sidecar、別Mac、旧対応macOSの検証環境を確保する。
4. 公開時にDeveloper ID署名・公証を行い、Gatekeeper有効の別Macで確認する。
5. 上記結果と既知制限を反映して、RC表記を外すか判断する。

## 7. 関連文書

- [DESIGN.md](DESIGN.md) — 設計思想・仕様
- [CHANGELOG.md](CHANGELOG.md) — 版ごとの開発履歴
- [REVIEW.md](REVIEW.md) — レビュー結果と未解決事項
- [README.md](README.md) — 利用者向け概要・ダウンロード
- [日本語の詳細開発履歴](docs/DEVELOPMENT_HISTORY_JA.md)
- [English development summary](docs/DEVELOPMENT_HISTORY_EN.md)
