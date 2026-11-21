# InnerCorners GE v0.12.0 Beta 1

[English](#english) | [日本語](#日本語)

## Download / ダウンロード

| Download | ダウンロード | Link |
| --- | --- | --- |
| **Recommended: GE Beta 1 — Apple Silicon** | **推奨：GE Beta 1 — Apple Silicon** | [Download Beta 1 ZIP](https://github.com/mochiya-tako/InnerCorners/releases/download/v0.12.0-beta.1/InnerCorners-GE-v0.12.0-beta.1-build71-arm64.app.zip) |
| Legacy comparison: RC7 — Apple Silicon | 旧版比較用：RC7 — Apple Silicon | [Download RC7 ZIP](https://github.com/mochiya-tako/InnerCorners/releases/download/v0.11.0-rc.7/InnerCorners-v0.11.0-rc.7-arm64.app.zip) |
| All releases | すべてのリリース | [GitHub Releases](https://github.com/mochiya-tako/InnerCorners/releases) |
| Source code (latest `main`) | 最新`main`のソースコード | [Download ZIP](https://github.com/mochiya-tako/InnerCorners/archive/refs/heads/main.zip) |

> [!IMPORTANT]
> **GE Beta 1 is the recommended download for normal testing. RC7 is retained only as a legacy comparison and fallback.**
>
> **通常の試用にはGE Beta 1を推奨します。RC7は旧版との比較・切り分け用として残しています。**
>
> GE Beta 1 is a locally validated GitHub pre-release. It is ad-hoc signed and has not been notarized or tested on another Mac. Review the release notes and keep the emergency bypass and quit paths available while testing.
>
> GE Beta 1はローカル検証済みのGitHubプレリリースです。アドホック署名で、公証および別のMacでの動作確認は未完了です。リリースノートを確認し、試用中は緊急通過と緊急終了を利用できる状態にしてください。

## English

InnerCorners is an experimental macOS menu bar app that makes the inner corners of multi-display layouts behave more like native outer hot corners. It places short, directional cursor barriers at display junctions and can run a separate action for each display and corner.

> [!WARNING]
> This is a beta, not a finished public release. It requires Accessibility permission because it monitors and constrains pointer movement. Keep the Option-key bypass and emergency quit shortcut available while testing.

### Highlights

- Recognizes all four corners of each display independently, including overlapping junctions in two- and three-display layouts.
- Creates directional 10–100 pt soft barriers at inner corners.
- Keeps enabled barriers active before, during, and after a hot-corner action.
- Uses Option as a temporary barrier bypass.
- Provides an independent Control–Option–Command–Q emergency shortcut that disables barriers, saves that state, and quits.
- Supports per-display, per-corner actions and 0–500 ms dwell times.
- Supports per-corner barrier policies, optional modifier requirements, and a speed-bump mode.
- Can suppress actions only, or both barriers and actions, for excluded and fullscreen apps.
- Prevents repeated activation until the pointer leaves the activation area.
- Follows display connection, disconnection, resolution, mirroring, and layout changes.
- Offers Japanese and English user interfaces.

### Available actions

- Follow the corresponding macOS Hot Corners setting
- Mission Control
- Application Windows / App Exposé
- Show Desktop
- Apps / Launchpad
- Quick Note
- Notification Center
- Lock Screen
- Start Screen Saver
- Put Display to Sleep
- Capture Selection
- Open Screenshot Toolbar
- Open an Application
- Run a Shortcut
- None

Outer corners set to “Follow macOS Hot Corners” are left to macOS to avoid double activation. Inner corners can use the matching system setting through InnerCorners.

### Safety design

- Barriers do not restart immediately after sleep or a real display-configuration change. The app waits at least five seconds and requires the pointer to reach a safe position away from the junction.
- Holding Option temporarily bypasses barriers and suppresses custom-zone actions.
- Dragging keeps the barrier active but suppresses the assigned action.
- The app remains visible in the Dock and Command–Tab so it can be brought forward and quit with Command–Q.
- The emergency shortcut works independently from the cursor event tap.
- The app does not add itself to Login Items.

### Requirements and permissions

- macOS 14 or later
- Apple Silicon build script (currently arm64)
- Accessibility permission for the cursor barrier and synthetic input paths

Normal launch does not automatically display the Accessibility prompt. The permission can be requested from the settings UI. The `--request-accessibility` argument is reserved for explicit verification runs.

### Build and test

With a matching full Xcode installation selected:

```sh
swift test
swift build -c release
```

To create the current arm64 app bundle and ZIP:

```sh
Scripts/build_app.sh
```

To create a source archive from the committed revision:

```sh
Scripts/build_source_archive.sh
```

The app bundle is ad-hoc signed. Developer ID signing, notarization, and operation on another Mac have not yet been verified.

### Verification status

GE Beta 1 build 71 has passed 90 automated tests and live testing on an Apple Silicon Mac with macOS 27.0.1. Tested scenarios include two- and three-display layouts, L-shaped and mirrored arrangements, strict and high-speed corner entry, full workspace-action cancellation combinations, physical display removal/reconnection, resolution changes, sleep/wake recovery, event-tap timeout recovery, temporary pause, excluded/fullscreen app suppression, speed-bump passage, emergency paths, settings persistence, and asynchronous completion diagnostics.

This does not establish compatibility with every Mac, display, pointing device, keyboard layout, or supported macOS version.

### Known limitations

- Long-duration CPU and memory behavior has not been measured.
- Sidecar has not been tested.
- Sustained contact with a 1000 Hz-class mouse has not been load-tested.
- Developer ID signing, notarization, and testing on another Mac remain incomplete.
- macOS 14, 15, and 26 have not received the same live action coverage as the current test system.
- Option-modified hot-corner assignments are intentionally unsupported because Option is reserved for emergency passage.
- Disabling the screen saver remains unimplemented because no sufficiently safe public API equivalent has been confirmed.

### License

InnerCorners is available under the [MIT License](LICENSE).

See [development plan](DEVELOPMENT_PLAN.md), [English development summary](docs/DEVELOPMENT_HISTORY_EN.md), and [full Japanese development history](docs/DEVELOPMENT_HISTORY_JA.md).

---

## 日本語

InnerCornersは、macOSのマルチディスプレイ接合部に短い方向別カーソル壁を設け、内側角を外周の標準ホットコーナーに近い感覚で利用できるようにする実験的なメニューバーアプリです。画面・コーナーごとに異なるアクションを割り当てられます。

> [!WARNING]
> 現在は一般公開版ではなくベータ版です。カーソルの監視と制約にアクセシビリティ権限を使用します。試用中はOptionキーによる一時通過と緊急終了ショートカットを利用できる状態にしてください。

### 主な機能

- 各ディスプレイの4隅を個別に認識し、2画面・3画面で複数の角が重なる接合点にも対応
- 内側角に10～100 ptの方向別ソフトバリアを生成
- ホットコーナーの発動前・発動中・発動後を通じ、壁が有効なら通過不能を維持
- Optionキーを押している間は壁を一時通過可能
- カーソル監視とは独立したControl–Option–Command–Qで、壁を無効として保存してから緊急終了
- 画面・コーナー別アクションと0～500 msの滞留時間
- コーナー別の壁ポリシー、修飾キー条件、押し続けて通過するスピードバンプ
- 除外アプリ／フルスクリーン時に、アクションのみまたは壁とアクションの両方を抑制
- 領域を出るまでの再発動抑制
- 画面の接続・切断、解像度、ミラーリング、配置変更への追従
- 日本語・英語UI

### 選択可能なアクション

- 対応するmacOS標準ホットコーナー設定に従う
- Mission Control
- アプリケーションウインドウ／App Exposé
- デスクトップを表示
- アプリ／Launchpad
- クイックメモ
- 通知センター
- 画面をロック
- スクリーンセーバを開始
- ディスプレイをスリープ
- 選択範囲を撮影
- スクリーンショットツールバーを開く
- アプリケーションを開く
- ショートカットを実行
- なし

外周コーナーで「macOSの標準設定に従う」を選んだ場合は、二重発火を避けるためmacOS自身に処理を任せます。内側角ではInnerCornersが対応する標準設定を補完します。

### 安全設計

- スリープ復帰または実際の画面構成変更後は、最低5秒が経過し、カーソルが接合部から離れた安全位置へ移動するまで壁を再開しません。
- Optionキーを押している間は壁を一時通過でき、独自領域アクションも抑止します。
- ドラッグ中は壁だけを維持し、割当アクションを発火しません。
- DockとCommand–Tabへ表示し、前面化してCommand–Qで終了できます。
- 緊急終了ショートカットはカーソルイベントタップから独立しています。
- アプリ自身がログイン項目へ追加することはありません。

### 動作条件と権限

- macOS 14以降
- 現在の配布用ビルドスクリプトはApple Silicon（arm64）向け
- カーソル壁と合成入力経路にアクセシビリティ権限が必要

通常起動ではアクセシビリティ許可ダイアログを自動表示しません。設定画面から明示的に要求できます。`--request-accessibility`引数は検証時の明示的な起動に限って使用します。

### ビルドとテスト

対応する完全版Xcodeを選択した環境では、通常は次を使用します。

```sh
swift test
swift build -c release
```

現在のarm64アプリとZIPを作成する場合：

```sh
Scripts/build_app.sh
```

コミット済みリビジョンからソースアーカイブを作成する場合：

```sh
Scripts/build_source_archive.sh
```

アプリはアドホック署名です。Developer ID署名、公証、別のMacでの動作は未確認です。

### 検証状況

GE Beta 1 build 71は90件の自動テストに合格し、Apple Silicon Mac・macOS 27.0.1で実機試験しています。2画面・3画面、L字・ミラーリング、厳密角・高速進入、ワークスペース4機能の全キャンセル組合せ、物理的な画面切断・再接続、解像度変更、スリープ復帰、イベントタップのタイムアウト復旧、一時停止、除外／フルスクリーン抑制、スピードバンプ、緊急経路、設定保持、非同期完了診断を確認しました。

これは、すべてのMac、ディスプレイ、ポインティングデバイス、キーボード配列、対応macOSでの互換性を保証するものではありません。

### 既知の制限

- 長時間常駐時のCPU・メモリ使用量は未測定
- Sidecarは未検証
- 1000 Hz級マウスを壁へ長時間押し当てた場合の負荷は未検証
- Developer ID署名、公証、別のMacでの試験は未完了
- macOS 14、15、26では現行試験環境と同等の実アクション試験を行っていない
- Optionは緊急通過に予約しているため、Option付きホットコーナー割当には非対応
- 十分安全な公開APIを確認できていないため、スクリーンセーバ無効化は未実装

### ライセンス

InnerCornersは[MIT License](LICENSE)で公開しています。

[今後の開発方針](DEVELOPMENT_PLAN.md)、[英語の開発概要](docs/DEVELOPMENT_HISTORY_EN.md)および[日本語の完全な開発履歴](docs/DEVELOPMENT_HISTORY_JA.md)を参照してください。
