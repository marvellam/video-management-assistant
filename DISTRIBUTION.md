# 发布方案

## 最终决策

当前正式路线是 Tauri 2 双平台便携应用：

- 不做 MSI、NSIS 或其他安装包。
- Windows 使用无需安装的单文件 EXE，`tauri.conf.json` 设置 `bundle.active: false`。
- macOS 使用 Universal `.app`，压缩为 ZIP 后发布，同时支持 Apple Silicon 与 Intel。
- 图标、前端资源和 `template.json` 全部编译进应用。
- Windows 用户可以直接把 EXE 放到桌面；Mac 用户解压后将 `.app` 放入“应用程序”。

Windows 版与 `mingisrookie/codex-switch` v0.1.5 的核心发布方式一致；Mac 版使用同一套跨平台源码单独构建。

## 为什么不再使用 PWA

PWA 能创建目录，但不能完整复现已验收功能：

- 浏览器不会暴露完整绝对路径。
- 浏览器不能在生成后自动打开 Finder/Windows 资源管理器。
- 本地目录授权体验与原生应用不同。

用户明确要求完整功能优先，因此 PWA 路线已撤销，不再作为当前交付方案。

## 为什么不使用 PowerShell 转 EXE

PS2EXE 可以快速把脚本包成壳，但仍依赖 PowerShell 执行模型，不是本项目需要的正规桌面应用架构。该尝试及工具已经从项目中清除。

正式版使用：

- TypeScript + HTML/CSS：界面。
- Rust：模板解析、输入校验和目录创建。
- Tauri dialog：原生目录选择器。
- Tauri opener 的 Rust 后端接口：生成后打开项目目录。

## 当前产物

- `Video-Management-Assistant.exe`：Windows x64 单文件便携应用，未签名。
- `Video-Management-Assistant-macOS-universal.zip`：macOS Universal App，Ad-hoc 签名。
- `SHA256SUMS.txt`：两个平台的 SHA-256 校验值。
- 当前公开版本：v1.1.0。

未签名 EXE 可以运行，但其他电脑从互联网下载后可能触发 SmartScreen；这与参考工具当前状态相同。等实际分发范围扩大后，再决定是否购买 Windows 代码签名证书。

## GitHub Releases

`.github/workflows/release.yml` 已启用双平台自动发布：

- `v*` 标签同时触发 Windows 与 macOS runner。
- 两个平台分别执行 TypeScript 与 Rust 质量检查。
- Windows 使用 `tauri build --no-bundle` 生成原始 EXE。
- macOS 构建 Universal App，并验证 `arm64`、`x86_64` 与 Ad-hoc 签名。
- Release 同时附带 EXE、Mac ZIP 与统一 SHA-256 文件。

## macOS 发布

Windows EXE 不能在 macOS 上运行；macOS 使用单独的 Universal `.app`，同时支持 Apple Silicon 与 Intel。

当前版本不加入 Apple Developer Program，采用 Ad-hoc 签名：

1. GitHub 的 `macos-latest` runner 构建 `universal-apple-darwin`。
2. `tauri.macos.conf.json` 使用 `signingIdentity: "-"`。
3. 发布 `Video-Management-Assistant-macOS-universal.zip`。
4. 用户首次打开时在“系统设置 → 隐私与安全性”中点击“仍要打开”。

该方案不清除 Gatekeeper 隔离属性，也不引导用户运行 `xattr`。如果未来需要下载后直接双击、无额外安全确认，再加入 Developer ID 签名与 Apple 公证。

## 本机构建性能

第一次构建需要编译四百多个 Rust/Tauri 依赖。实测在系统提交内存接近耗尽时，并行编译会导致 `rustc` 失败；单线程首次 release 构建约15分钟。

清理内存并完成首次缓存后，2并发的小改动 release 重建约2分10秒。`Build-Release.ps1` 因此默认使用 `Jobs=2`，避免再次压满系统，同时比单线程明显更快。
