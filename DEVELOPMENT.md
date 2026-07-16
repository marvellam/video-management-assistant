# 开发与发布

本文面向需要修改源码、重新编译或维护 GitHub Release 的开发者。普通用户只需要按 [README](README.md) 下载对应系统的成品。

## 技术结构

- `src/`：TypeScript 界面与窗口交互。
- `src-tauri/`：Rust 文件系统核心与 Tauri 配置。
- `template.json`：官方推荐模板的唯一真源，编译时嵌入应用且保持只读。
- `templates.json`：用户在软件内保存的自定义模板，运行时写入 Tauri 应用配置目录，不进入仓库。
- `src-tauri/tauri.macos.conf.json`：Mac 原生窗口与 Ad-hoc 签名配置。
- `.github/workflows/release.yml`：Windows 与 Mac 自动构建和发布流程。
- `Generate-VideoProject.ps1`：早期 Windows 原型，保留作行为对照。

自定义模板由 Rust 层统一校验：最多 8 层、200 个文件夹，同级目录不能重名，并同时排除 Windows 与 macOS 不允许的路径名称。项目根目录固定使用 `日期_项目名称`，避免不同模板造成项目入口失去一致性。

## Windows 本机构建

需要 Node.js、Rust stable 与 Visual Studio 2022 C++ Build Tools。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Build-Release.ps1
```

脚本会执行前端检查、Rust 测试、格式检查、clippy 和 Tauri release 构建。只重建、不重复完整检查：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Build-Release.ps1 -SkipChecks
```

默认使用 2 个 Rust 编译任务，兼顾构建速度与内存压力。第一次需要编译 Tauri 依赖，之后会复用 Cargo 缓存。

## Mac 本机构建

需要 Node.js、Rust stable 与 Xcode Command Line Tools。Universal 2 应用需要两个 Rust target：

```bash
rustup target add aarch64-apple-darwin x86_64-apple-darwin
npm ci
npm run typecheck
VITE_TARGET_PLATFORM=macos npm run tauri -- build --target universal-apple-darwin --bundles app
```

产物采用 Ad-hoc 签名，同时支持 Apple Silicon 与 Intel。正式发布前应使用 `lipo -archs` 检查两个架构，并使用 `codesign --verify --deep --strict` 检查签名。

## GitHub 发布

推送 `v*` 标签后，GitHub Actions 会：

1. 在 Windows 与 Mac runner 分别执行 TypeScript 和 Rust 检查。
2. 构建 Windows 便携 EXE 与 macOS Universal App。
3. 验证 Mac 的 `arm64`、`x86_64` 架构和 Ad-hoc 签名。
4. 在同一个 Release 发布两个平台的应用与 `SHA256SUMS.txt`。

Release 的用户说明以 `.github/RELEASE_NOTES.md` 为模板，不自动展示提交记录；修改下载方式或首次运行要求时，应同步更新该文件。

正式资产名称固定为：

- `Video-Management-Assistant.exe`
- `Video-Management-Assistant-macOS-universal.zip`
- `SHA256SUMS.txt`

如果未来需要减少 Windows SmartScreen 或 Mac Gatekeeper 提示，应分别加入 Windows 代码签名，以及 Apple Developer ID 签名与公证。
