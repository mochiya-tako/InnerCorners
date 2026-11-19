# InnerCorners v0.11.0 RC7

[English](#english) | [日本語](#日本語)

## Download / ダウンロード

| Download | ダウンロード | Link |
| --- | --- | --- |
| Latest RC app — Apple Silicon | 最新RCアプリ — Apple Silicon | [Download RC7 ZIP](https://github.com/mochiya-tako/InnerCorners/releases/download/v0.11.0-rc.7/InnerCorners-v0.11.0-rc.7-arm64.app.zip) |
| All releases | すべてのリリース | [GitHub Releases](https://github.com/mochiya-tako/InnerCorners/releases) |
| Source code (latest `main`) | 最新`main`のソースコード | [Download ZIP](https://github.com/mochiya-tako/InnerCorners/archive/refs/heads/main.zip) |

> [!IMPORTANT]
> RC7 is a pre-release for testing. It is ad-hoc signed and has not been notarized or tested on another Mac. Review the release notes and keep the emergency bypass and quit paths available while testing.
>
> RC7は試用向けのプレリリースです。アドホック署名で、公証および別のMacでの動作確認は未完了です。リリースノートを確認し、試用中は緊急通過と緊急終了を利用できる状態にしてください。

## English

InnerCorners is an experimental macOS menu bar app that makes the inner corners of multi-display layouts behave more like native outer hot corners. It places short, directional cursor barriers at display junctions and can run a separate action for each display and corner.

> [!WARNING]
> This is a release candidate, not a finished public release. It requires Accessibility permission because it monitors and constrains pointer movement. Keep the Option-key bypass and emergency quit shortcut available while testing.

### Highlights

- Recognizes all four corners of each display independently, including overlapping junctions in two- and three-display layouts.
- Creates directional 10–100 pt soft barriers at inner corners.
- Keeps enabled barriers active before, during, and after a hot-corner action.
- Uses Option as a temporary barrier bypass.
- Provides an independent Control–Option–Command–Q emergency shortcut that disables barriers, saves that state, and quits.
- Supports per-display, per-corner actions and 0–500 ms dwell times.
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

RC7 has been exercised on an Apple Silicon Mac with macOS 27.0.1 using two- and three-display horizontal, vertical, L-shaped, convex, T-shaped, and mirrored layouts. Barrier ownership, strict-corner contact, high-speed entry, reactivation, display removal/reconnection, sleep/wake recovery, the emergency paths, settings persistence, and the listed actions were tested in the configurations recorded in the development history.

This does not establish compatibility with every Mac, display, pointing device, keyboard layout, or supported macOS version.

### Known limitations

- Long-duration CPU and memory behavior has not been measured.
- Sidecar has not been tested.
- Sustained contact with a 1000 Hz-class mouse has not been load-tested.
- Developer ID signing, notarization, and testing on another Mac remain incomplete.
- macOS 14, 15, and 26 have not received the same live action coverage as the current test system.
- Option-modified hot-corner assignments are intentionally unsupported because Option is reserved for emergency passage.
- Disabling the screen saver remains unimplemented because no sufficiently safe public API equivalent has been confirmed.

See [development plan](DEVELOPMENT_PLAN.md), [English development summary](docs/DEVELOPMENT_HISTORY_EN.md), and [full Japanese development history](docs/DEVELOPMENT_HISTORY_JA.md).

---

## 日本語

InnerCornersは、macOSのマルチディスプレイ接合部に短い方向別カーソル壁を設け、内側角を外周の標準ホットコーナーに近い感覚で利用できるようにする実験的なメニューバーアプリです。画面・コーナーごとに異なるアクションを割り当てられます。

> [!WARNING]
> 現在は一般公開版ではなくリリース候補です。カーソルの監視と制約にアクセシビリティ権限を使用します。試用中はOptionキーによる一時通過と緊急終了ショートカットを利用できる状態にしてください。

### 主な機能

- 各ディスプレイの4隅を個別に認識し、2画面・3画面で複数の角が重なる接合点にも対応
- 内側角に10～100 ptの方向別ソフトバリアを生成
- ホットコーナーの発動前・発動中・発動後を通じ、壁が有効なら通過不能を維持
- Optionキーを押している間は壁を一時通過可能
- カーソル監視とは独立したControl–Option–Command–Qで、壁を無効として保存してから緊急終了
- 画面・コーナー別アクションと0～500 msの滞留時間
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

RC7はApple Silicon Mac・macOS 27.0.1で、2画面および3画面の横一列、縦一列、L字、凸型、T字、ミラーリング構成を使って試験しています。開発履歴に記録した構成では、壁の所有判定、厳密な角への接触、高速進入、再発動、画面の切断・再接続、スリープ復帰、安全な終了経路、設定保持、各アクションを確認しました。

これは、すべてのMac、ディスプレイ、ポインティングデバイス、キーボード配列、対応macOSでの互換性を保証するものではありません。

### 既知の制限

- 長時間常駐時のCPU・メモリ使用量は未測定
- Sidecarは未検証
- 1000 Hz級マウスを壁へ長時間押し当てた場合の負荷は未検証
- Developer ID署名、公証、別のMacでの試験は未完了
- macOS 14、15、26では現行試験環境と同等の実アクション試験を行っていない
- Optionは緊急通過に予約しているため、Option付きホットコーナー割当には非対応
- 十分安全な公開APIを確認できていないため、スクリーンセーバ無効化は未実装

[今後の開発方針](DEVELOPMENT_PLAN.md)、[英語の開発概要](docs/DEVELOPMENT_HISTORY_EN.md)および[日本語の完全な開発履歴](docs/DEVELOPMENT_HISTORY_JA.md)を参照してください。
