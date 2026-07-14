# 发布方案

## 最终决策

当前正式路线是 Tauri 2 Windows 便携 EXE：

- 不做 MSI、NSIS 或其他安装包。
- `tauri.conf.json` 设置 `bundle.active: false`。
- 最终只交付一个可直接双击的 `视频管理助手.exe`。
- 图标、前端资源和 `template.json` 全部编译进 EXE。
- 用户可直接把 EXE 放到桌面，不需要创建安装器快捷方式。

这与 `mingisrookie/codex-switch` v0.1.5 的核心发布方式一致，但本项目保留了跨平台源码边界。

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

- 文件：`release/视频管理助手.exe`
- 平台：Windows x64
- 形式：单文件便携应用，无安装器
- 版本：1.0.0
- 签名：未签名

未签名 EXE 可以运行，但其他电脑从互联网下载后可能触发 SmartScreen；这与参考工具当前状态相同。等实际分发范围扩大后，再决定是否购买 Windows 代码签名证书。

## GitHub Releases

`.github/workflows/release.yml` 已准备好自动发布：

- `v*` 标签触发 Windows runner。
- 执行 TypeScript 与 Rust 质量检查。
- 使用 `tauri build --no-bundle` 生成原始 EXE。
- Release 附带 EXE 与 SHA-256 文件。

## macOS 可能性

当前不承诺一个 EXE 同时运行于 Windows 和 macOS。macOS 必须单独构建 `.app`。

现有目录核心、模板、界面、原生选择器和打开目录能力均采用跨平台实现。将来新增 macOS 时，主要工作是：

1. 在 `macos-latest` 上构建。
2. 输出 `.app.zip` 或 `.dmg`。
3. 决定是否接受首次“仍要打开”提示，或加入 Apple Developer ID 签名与公证。

无需重新设计目录生成逻辑。

## 本机构建性能

第一次构建需要编译四百多个 Rust/Tauri 依赖。实测在系统提交内存接近耗尽时，并行编译会导致 `rustc` 失败；单线程首次 release 构建约15分钟。

清理内存并完成首次缓存后，2并发的小改动 release 重建约2分10秒。`Build-Release.ps1` 因此默认使用 `Jobs=2`，避免再次压满系统，同时比单线程明显更快。
