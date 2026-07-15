# 视频管理助手项目记录

最后更新：2026-07-15

## 目标

替代已下架 Gate 软件中团队实际使用的“标准目录一键生成”能力，让新同事无需手工逐层创建视频项目文件夹。

## 当前决策

- 第一版只解决目录初始化，不复刻读卡、素材校验或数据比对能力。
- 固定目录是唯一会落盘的内容；末层文件命名示例只保留为说明，不创建成文件夹。
- 目录结构以 `template.json` 为真源，图形界面和命令行共用同一套生成核心。
- 日常入口为双击启动器；PowerShell 命令行仅用于验证和后续自动化。
- 已存在的项目只补建缺失目录，不覆盖、移动或删除任何内容。
- 正式图标方向已选定为 A“文件夹 + 目录树”。
- 正式应用名称由“视频项目目录生成器”调整为“视频管理助手”。
- 正式封装确定为 Tauri 2 双平台便携应用，不生成安装包；Windows 用户直接运行 EXE，Mac 用户解压后将 `.app` 放入“应用程序”。
- PWA 因无法显示完整路径、无法生成后打开系统文件管理器而被否决。
- PS2EXE 转壳因不符合正规桌面应用架构而撤销，相关产物和工具已清理。
- Windows 与 macOS 共享 TypeScript 界面、Rust 目录核心和模板；平台配置只处理窗口装饰与发布形式，不互相覆盖。
- macOS 采用 Universal 2 构建，同一 ZIP 同时支持 Apple Silicon 与 Intel；当前使用 Ad-hoc 签名，不要求 Apple Developer Program。

## 交付物

- `启动目录生成器.cmd`：新同事双击入口。
- `Generate-VideoProject.ps1`：图形界面、输入校验和生成核心。
- `template.json`：固定目录与非目录命名说明。
- `README.md`：使用方法、目录树和模板维护说明。
- `ICON_OPTIONS.md`：应用图标候选与正式导出要求。
- `DISTRIBUTION.md`：跨平台重构、安装包与 GitHub Releases 方案。
- `MAC_INSTALL.md`：Mac 下载、校验、首次放行与 Agent 安装说明。
- `src/`：正式 TypeScript 界面。
- `src-tauri/`：正式 Rust/Tauri 应用与测试。
- `Build-Release.ps1`：正规单文件 EXE 构建入口。
- `release/视频管理助手.exe`：当前 Windows x64 正式便携产物。
- GitHub Release：正式发布 `Video-Management-Assistant.exe`、`Video-Management-Assistant-macOS-universal.zip` 与统一校验文件。

## 已验证

- Windows PowerShell 5.1 可正确读取中文脚本和模板。
- 当前模板首次创建 21 个目录：1 个项目根目录和 20 个固定目录。
- 对同一项目再次运行时，新建 0 个、识别已存在 21 个。
- 三条末层命名说明均未被创建为文件夹。
- 非法日期会停止生成并返回明确提示。
- 图形界面进程可正常启动，未出现启动即退出。
- 用户已确认目录生成功能没有问题。
- V1.1 已将 WinForms 工程界面重构为 WPF 双栏界面，并完成 125% DPI 下的实机截图检查。
- V1.1 视觉采用深炭黑、暖白和香槟金；输入焦点、复选框、目录树与完整 8 层预览均已检查。
- 用户随后明确纠正审美规则：稳定偏好是克制、极简、低饱和与自然质感，不应把黑金配色固化成默认命令。
- V1.2 保留双栏结构，改为低饱和暖灰棕与米白的大地色关系，并删除装饰性英文、口号和重复说明。
- V1.2 已完成 125% DPI 实机截图检查，字段、完整目录树和操作层级均清晰可见。
- 用户明确否定 V1.2 的视觉结果，并要求直接尝试苹果风；这属于当前工具的设计方向，不写成跨项目固定偏好。
- V1.3 保留双栏信息结构，改为浅灰背景、白色悬浮卡片、系统蓝主操作与 8px 圆角输入。
- V1.3 已完成 125% DPI 实机截图检查，界面层级、输入焦点和完整目录树显示正常。
- 用户提供新的简约 B 端界面参考图；该图只作为当前工具的视觉参考，不升级为跨项目固定偏好。
- V1.4 将左侧表单改为深灰圆角功能卡，右侧保留白色主预览卡，灰色画布上只使用橙色作为操作强调。
- V1.4 背景大字使用中文“项目”，未照搬参考图中与本工具无关的菜单、英文标题和数据模块。
- V1.4 已完成 125% DPI 实机截图检查，输入焦点、橙色状态与完整目录树显示正常。
- V1.5 将窗口左上角改为“项目管理系统”，左侧主标题恢复为“给项目一个清晰的开始”及其说明文案。
- V1.5 删除没有新增信息的背景大字“项目”，保持灰色画布的留白。
- 目录模板升级为版本 2，在 `3.素材` 下新增 `文档` 文件夹。
- V1.6 已核实本机安装的字体族名称为 `Source Han Sans SC`，并统一应用到标题、表单、按钮和目录预览。
- V1.6 将保存位置改为一个完整圆角容器，路径输入与“选择”按钮共用外框，仅用一条内部分隔线区分。
- V1.7 定位到文字发糊的底层原因：两张内容卡片直接使用 `DropShadowEffect`，导致文字随父容器进入离屏栅格化并失去 ClearType；窗口同时只有 System-aware DPI 感知。
- V1.7 将阴影拆到不含文字的独立背景层，并全局启用 `ClearType`、`Display` 文字排版、布局取整与设备像素对齐。
- V1.7 为 PowerShell 承载的 WPF UI 线程设置 Per-Monitor V2 DPI 感知；实测窗口从 `System-aware` 升级为 `Per-monitor-aware`，并通过 `AreDpiAwarenessContextsEqual(..., PER_MONITOR_AWARE_V2)` 验证。
- 正式版已迁移到 Tauri 2 + TypeScript + Rust，并设置 `bundle.active=false`，只生成原始便携 EXE。
- TypeScript typecheck、Vite production build、Rust fmt、4 个 Rust 单元测试与 clippy `-D warnings` 均通过。
- Rust 单元测试验证：首次创建21个目录，第二次识别21个已有目录，`3.素材/文档` 存在，三条命名说明不落盘，同名文件不会被目录覆盖。
- 真实 EXE 桌面验收通过：原生目录选择器显示完整路径，第一次生成显示“新建21个 · 已有0个”并自动打开资源管理器；第二次显示“新建0个 · 已有21个”。
- 正式 EXE 约9.04MB，版本1.0.0，图标 A 已嵌入；当前未签名。
- 首次 release 单线程构建约14分56秒；依赖缓存后2并发重建约2分10秒。构建脚本默认2并发以兼顾速度与内存。
- Tauri 窗口权限已显式加入关闭、最小化、切换最大化和拖动；公开下载版通过 Windows 辅助功能树精确验收，最小化后系统状态为 minimized，关闭后进程退出。
- GitHub Actions 在全新 Windows runner 上完成 TypeScript 检查、4 个 Rust 测试、fmt、clippy 和 release 构建，工作流成功。
- v1.0.0 公开资产已从无登录的 `releases/latest/download` 地址重新下载，EXE 与 `SHA256SUMS.txt` 的 SHA-256 一致，下载版标题、产品名和版本均正确。
- GitHub 会把纯中文 Release 文件名规范化为 `default.exe`；正式发布资产因此固定为 `Video-Management-Assistant.exe`，Agent 校验后在桌面保存为 `视频管理助手.exe`。
- 后续 GitHub 构建已加入 Rust 缓存并改为4并发；本机构建仍保持2并发，避免当前机器内存再次被打满。
- v1.0.0 Release 链接已通过飞书发送给当前用户，并完成消息内容回读验证。
- v1.1.0 双平台工作流已在 GitHub 的真实 Windows 与 macOS runner 上通过：类型检查、4 个 Rust 测试、fmt、clippy 和正式构建均成功。
- Windows v1.1.0 产物为便携 EXE，窗口最小化和关闭已通过直接桌面回归测试。
- macOS v1.1.0 产物为 Universal 2 `.app`；工作流用 `lipo` 同时验证 `arm64` 与 `x86_64`，并通过 `codesign --verify --deep --strict`。
- Mac ZIP 已下载解包检查：应用名、显示名均为“视频管理助手”，版本 1.1.0，标识符为 `cn.yiyizhijian.video-management-assistant`，最低系统版本为 macOS 11.0。
- 无开发者账号的边界已固定：Mac 版本可以公开下载和正常运行，但首次打开需要用户在“系统设置 → 隐私与安全性”中点击“仍要打开”；不自动移除隔离属性。
- v1.1.0 已正式发布；从无需登录的 `releases/latest/download` 地址重新下载 Windows EXE、Mac ZIP 和 `SHA256SUMS.txt` 后，两份应用的 SHA-256 均与校验文件一致。
- 公开下载的 Windows EXE 已再次验证版本为 1.1.0，可正常启动并响应关闭；公开 Mac ZIP 已再次解包读取 `Info.plist`，中文应用名、版本 1.1.0 与 macOS 11.0 最低系统要求正确。

## 当前状态

V2.1 Windows + macOS 双平台便携版已完成。正式名称为“视频管理助手”；Windows 保留独立 EXE，Mac 新增 Universal 2 `.app`，两个系统从同一个 GitHub Release 下载各自资产。

公开仓库：`https://github.com/marvellam/video-management-assistant`

v1.1.0 Release：`https://github.com/marvellam/video-management-assistant/releases/tag/v1.1.0`

## 待确认

- 在团队实际 NAS 目录上试建一个测试项目，确认账号权限和路径长度。
- 收集一位新同事对 V2.0 EXE 的首次运行、清晰度和界面文案反馈。
- 收集一台 Apple Silicon Mac 和一台 Intel Mac 的首次打开反馈；架构与签名已由 GitHub runner 自动验证。

## 风险与边界

- 工具不会修改现有文件，但 NAS 账号必须具备目标路径的创建权限。
- 当前 Windows EXE 未签名，Mac `.app` 为 Ad-hoc 签名；跨公司或大范围分发时应考虑 Windows 代码签名和 Apple Developer ID + notarization，以减少系统安全提示。
- 模板内名称发生变化时，应先在测试目录验证，再分发给团队。
