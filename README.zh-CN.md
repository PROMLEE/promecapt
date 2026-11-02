<div align="center">
  <img src="assets/app-icon.svg" width="88" alt="Promecapt">
  <h1>Promecapt</h1>
  <p><strong>截图、标注，固定在眼前。</strong></p>
  <p>适用于 macOS 的开源截图工具，支持标注、图片置顶和 GIF 录制。</p>
  <p><a href="https://github.com/PROMLEE/promecapt/releases/latest">下载</a> · <a href="docs/INSTALL.md">安装指南</a> · <a href="https://github.com/PROMLEE/promecapt/issues">Issues</a></p>
  <p>macOS 13+ · Apple Silicon & Intel · MIT</p>
  <p><a href="README.md">English</a> · <a href="README.ko.md">한국어</a> · <a href="README.ja.md">日本語</a> · <a href="README.zh-CN.md">简体中文</a></p>
</div>

![在真实 Promecapt 编辑器中，为示例画面添加矩形、箭头和编号。](assets/screenshots/editor.jpg)

<p align="center"><sub>真实应用截图 · 示例数据 · 英语界面</sub></p>

## 主要功能

| 功能 | 支持内容 |
| --- | --- |
| **截图** | 区域、窗口和可访问的应用内元素 |
| **标注** | 画笔、形状、箭头、文字、编号，可重新选择修改 |
| **遮盖** | 马赛克、模糊、不透明黑块 |
| **置顶** | 图片和动态 GIF，缩放、透明度、分组 |
| **OCR** | 选定文字区域，本地识别韩语和英语 |
| **GIF** | 5–30fps，分辨率和时长设置，预览、复制、置顶、保存 |

界面：한국어 · English · 日本語 · 简体中文。[功能限制（英语）](docs/FEATURES.md) · 1.1.0 起支持[手动和可选自动更新](docs/AUTO-UPDATE.md)。1.0.0 用户需先手动安装一次。

<details>
<summary>GIF 设置</summary>

![GIF 设置](assets/screenshots/gif-settings.jpg)

</details>

## 安装

1. 从 [Releases](https://github.com/PROMLEE/promecapt/releases/latest) 下载 **Apple Silicon (arm64)** 或 **Intel (x86_64)** DMG。
2. 打开 DMG，将 **Promecapt.app** 拖至 **Applications**，然后推出磁盘映像。
3. 启动后允许**屏幕录制**和**辅助功能**权限。

**目前尚未经过 Apple 公证。** 如果 macOS 阻止了可信下载，请参阅[安装指南（英语）](docs/INSTALL.md)。本地构建无需付费开发者账户。

## 快捷键

| 操作 | 快捷键 |
| --- | --- |
| 截图 | `⌥⌘1` |
| 复制 / 置顶 | `⌘C` / `⌘Enter` |
| 置顶剪贴板 | `⌥⌘3` |
| 显示 / 隐藏置顶图片 | `⌥⌘4` |
| 上一个 / 下一个截图 | `,` / `.` |
| 取消 / 关闭置顶 | `Esc` |

在设置 → 快捷键中可改为 F1 等按键。媒体键模式下请使用 `Fn+F1`。

## 从源码构建

需要免费的 Apple Command Line Tools 和 Swift 5.9+。无需付费开发者账户或签名证书。

```sh
xcode-select --install # complete the installer before continuing
git clone --branch v1.1.6 --depth 1 https://github.com/PROMLEE/promecapt.git
cd promecapt
bash scripts/package.sh
mkdir -p "$HOME/Applications"
ditto dist/Promecapt.app "$HOME/Applications/Promecapt.app"
open "$HOME/Applications/Promecapt.app"
```

## 文档

[安装指南](docs/INSTALL.md) · [使用指南](docs/USAGE.md) · [贡献指南](CONTRIBUTING.md) · [Changelog](CHANGELOG.md) · [llms.txt](llms.txt)

图片和 OCR 均在本地处理，无上传和分析收集。历史记录还会保存完整屏幕。[存储与隐私（英语）](docs/USAGE.md#privacy--storage)。

[MIT](LICENSE) — 允许个人和商业使用。
