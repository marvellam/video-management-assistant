# 视频管理助手

一键创建标准的视频项目目录，让素材、工程文件、字幕和成片从一开始就保持清晰。

![界面预览](assets/interface-preview.png)

## 下载

| 系统 | 下载 | 使用方式 |
| --- | --- | --- |
| Windows 10 / 11 | [下载 Windows 版](https://github.com/marvellam/video-management-assistant/releases/latest/download/Video-Management-Assistant.exe) | 下载后直接双击 |
| macOS 11 或更高版本 | [下载 Mac 版](https://github.com/marvellam/video-management-assistant/releases/latest/download/Video-Management-Assistant-macOS-universal.zip) | 解压后移入“应用程序” |

Mac 版同时支持 Apple 芯片和 Intel。普通用户不需要安装 Node.js、Rust、Visual Studio 或 Xcode。

需要核验文件时，可下载 [SHA-256 校验文件](https://github.com/marvellam/video-management-assistant/releases/latest/download/SHA256SUMS.txt)。

## 使用

1. 填写项目名称与日期。
2. 选择保存位置。
3. 保持“生成后打开项目目录”勾选。
4. 点击“生成目录”。

项目根目录格式为 `日期_项目名称`，例如 `20260714_常彧老师播客`。

如果目录已经存在，软件只补建缺失文件夹，不会覆盖、移动或删除已有内容。

## 自定义目录模板

内置的官方视频模板可以直接使用，也可以在软件内点击“设计模板”创建自己的目录结构：

- 基于官方模板复制后修改，或从空白模板开始。
- 添加一级目录、同级目录和子目录。
- 修改目录名称，使用“上移 / 下移”调整同级顺序。
- 保存后的模板只存放在当前电脑，之后可以从“目录模板”中直接选择。

官方模板保持只读，因此自定义修改不会影响默认结构。选择某个模板后，“生成预览”和实际创建的文件夹会使用同一套结构。

## 生成的目录

```text
日期_项目名称
├─ 1.工程文件
├─ 2.原始素材
│  ├─ 视频
│  ├─ 图片
│  └─ 音频
├─ 3.素材
│  ├─ 视频
│  ├─ 图片
│  ├─ 文档
│  ├─ 音乐
│  └─ 音效
├─ 4.字幕
├─ 5.通用素材
│  ├─ 片头片尾
│  └─ logo
├─ 6.封面
├─ 7.导出
│  ├─ 小样
│  └─ 成片
└─ 8.归档
```

上面是官方推荐模板。原始视频、小样和成片的命名示例只是提醒，不会被创建为文件夹。

## 首次运行

- Windows：当前版本未做代码签名，系统可能显示 SmartScreen 提示。确认文件来自本仓库后，选择“更多信息 → 仍要运行”。
- Mac：首次打开可能提示无法验证开发者。前往“系统设置 → 隐私与安全性”，找到“视频管理助手”并选择“仍要打开”。详见 [Mac 安装说明](MAC_INSTALL.md)。

## 让 Agent 帮你安装

把本仓库链接发给能操作电脑的 Agent，并让它下载与你系统对应的最新 Release。Windows 的完整验收要求见 [Agent 安装说明](AGENT_INSTALL.md)，Mac 见 [Mac 安装说明](MAC_INSTALL.md)。

开发、构建和发布说明见 [DEVELOPMENT.md](DEVELOPMENT.md)。本项目采用 [MIT License](LICENSE)。
