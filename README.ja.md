<div align="center">
  <img src="assets/app-icon.svg" width="88" alt="Promecapt">
  <h1>Promecapt</h1>
  <p><strong>キャプチャして、編集して、そばに固定。</strong></p>
  <p>macOS向けオープンソースのスクリーンショットツール。注釈・画像固定・GIF録画に対応。</p>
  <p><a href="https://github.com/PROMLEE/promecapt/releases/latest">ダウンロード</a> · <a href="docs/INSTALL.md">インストール</a> · <a href="https://github.com/PROMLEE/promecapt/issues">Issues</a></p>
  <p>macOS 13+ · Apple Silicon & Intel · MIT</p>
  <p><a href="README.md">English</a> · <a href="README.ko.md">한국어</a> · <a href="README.ja.md">日本語</a> · <a href="README.zh-CN.md">简体中文</a></p>
</div>

![実際のPromecaptエディタで、サンプル画像に矩形・矢印・番号を追加した画面。](assets/screenshots/editor.jpg)

<p align="center"><sub>実際のアプリ画面 · サンプルデータ · 英語UI</sub></p>

## 主な機能

| 機能 | 対応内容 |
| --- | --- |
| **キャプチャ** | 領域・ウィンドウ・アクセシブルなアプリ要素 |
| **注釈** | ペン・図形・矢印・文字・番号、再選択して編集 |
| **マスキング** | モザイク・ぼかし・不透明な黒塗り |
| **固定** | 画像・アニメーションGIF、ズーム・透明度・グループ |
| **OCR** | 選択領域の韓国語・英語をローカル認識 |
| **GIF** | 5〜30fps、解像度・時間設定、プレビュー・コピー・固定・保存 |

UI: 한국어 · English · 日本語 · 简体中文。[機能の制限（英語）](docs/FEATURES.md) · 1.1.0から[手動・任意の自動更新](docs/AUTO-UPDATE.md)に対応。1.0.0からは一度手動でインストールしてください。

<details>
<summary>GIF設定</summary>

![GIF設定](assets/screenshots/gif-settings.jpg)

</details>

## インストール

1. [Releases](https://github.com/PROMLEE/promecapt/releases/latest)から **Apple Silicon (arm64)** または **Intel (x86_64)** のDMGを取得します。
2. DMGを開き、**Promecapt.app** を **Applications** にドラッグしてから、ディスクを取り出します。
3. 起動後、**画面収録**と**アクセシビリティ**を許可します。

**Apple公証は未対応です。** 信頼するダウンロードがブロックされた場合は[インストールガイド（英語）](docs/INSTALL.md)をご覧ください。ローカルビルドに有料開発者アカウントは不要です。

## ショートカット

| 操作 | ショートカット |
| --- | --- |
| キャプチャ | `⌥⌘1` |
| コピー / 固定 | `⌘C` / `⌘Enter` |
| クリップボードを固定 | `⌥⌘3` |
| 固定画像の表示 / 非表示 | `⌥⌘4` |
| 前 / 次のキャプチャ | `,` / `.` |
| キャンセル / 固定を閉じる | `Esc` |

設定 → ショートカットでF1などに変更できます。メディアキーモードでは `Fn+F1` を使用します。

## ソースからビルド

無料のApple Command Line ToolsとSwift 5.9以降が必要です。有料開発者アカウント・証明書は不要です。

```sh
xcode-select --install # complete the installer before continuing
git clone --branch v1.1.4 --depth 1 https://github.com/PROMLEE/promecapt.git
cd promecapt
bash scripts/package.sh
mkdir -p "$HOME/Applications"
ditto dist/Promecapt.app "$HOME/Applications/Promecapt.app"
open "$HOME/Applications/Promecapt.app"
```

## ドキュメント

[インストール](docs/INSTALL.md) · [使い方](docs/USAGE.md) · [貢献ガイド](CONTRIBUTING.md) · [Changelog](CHANGELOG.md) · [llms.txt](llms.txt)

画像・OCRはローカル処理。アップロード・分析収集なし。履歴には画面全体も保存されます。[保存とプライバシー（英語）](docs/USAGE.md#privacy--storage)。

[MIT](LICENSE) — 個人・商用利用可能。
