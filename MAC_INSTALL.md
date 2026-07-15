# 在 Mac 上安装视频管理助手

当前 macOS 版本采用 Ad-hoc 签名，不需要 Apple Developer Program。它可以正常运行，但首次打开需要由用户在系统设置中明确放行。

## 下载与校验

1. 从 GitHub 最新 Release 下载 `Video-Management-Assistant-macOS-universal.zip` 和 `SHA256SUMS.txt`。
2. 解压 ZIP，得到 `视频管理助手.app`。
3. 将应用拖入“应用程序”文件夹。

ZIP 同时支持 Apple Silicon 与 Intel Mac。

## 首次打开

1. 双击“视频管理助手”。macOS 会提示无法验证开发者或无法检查应用。
2. 打开“系统设置 → 隐私与安全性”。
3. 在安全性区域找到刚刚被拦截的“视频管理助手”，点击“仍要打开”。
4. 输入当前 Mac 的登录密码并确认。

系统会把它保存为例外，以后可以像普通应用一样双击打开。受公司管理策略限制的 Mac 可能不允许用户自行放行，需要联系管理员。

## 给 Agent 的安装指令

```text
请从 GitHub 仓库 marvellam/video-management-assistant 的最新 Release 下载 Video-Management-Assistant-macOS-universal.zip 和 SHA256SUMS.txt，校验 SHA-256，解压后把“视频管理助手.app”放入当前用户可用的“应用程序”目录；不要自动绕过 Gatekeeper，不要执行 xattr 清除隔离属性，首次放行由用户本人在“系统设置 → 隐私与安全性”中完成。
```
