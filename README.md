# 🐳 大肥鱼 · DeepSeek Harness 启动器

[English](README.en.md) | 中文

DSH(DeepSeek Harness)的**一键开关** —— Windows 是右下角托盘,macOS 是右上角菜单栏。
**独立于 dsh 进程**,类似 Steam 的启动器。

本仓库还附带 macOS 上的 **🦞 OpenClaw 龙虾**(OpenClaw 网关的一键开关,同一套骨架)。

## 我该用哪个

| 平台 | 程序 | 形态 | 源码 |
|---|---|---|---|
| **Windows** | `大肥鱼.exe` | 右下角**托盘** | [`WhaleTray.cs`](WhaleTray.cs) |
| **macOS** | `大肥鱼.app` | 右上角**菜单栏** | [`macos/`](macos/) |
| **macOS** | `OpenClaw.app` 🦞 | 右上角**菜单栏** | [`openclaw/`](openclaw/) |

## 功能对照

| 操作 | Windows | macOS |
|---|---|---|
| 开关服务 | 右键 → 开启/关闭 | 同 |
| 唤起 Web | 左键 / 双击鲸鱼 | 左键 |
| 切到已开的标签 | 9335 端口 + **配套浏览器扩展** | **AppleScript 直连**,不需要扩展 |
| 重启服务 | 右键 → 重启 | 同 |
| 充值 | 右键 → 充值 | 同 |
| 退出 | 先关 dsh 再退出 | 同 |
| 状态刷新 | 每 2 秒 | 每 3 秒(TCP 探测) |
| 形态 | 托盘 + 隐藏控制台 | 菜单栏,天然静默 |

> **macOS 版不需要浏览器扩展** —— Chromium 系浏览器把标签页暴露给 AppleScript,
> 直接选标签就行。Windows 才需要那套端口轮询 + 扩展。

⚠️ **macOS 版有一个 Windows 没有的大坑:TCC 权限。**
**改代码 / 换机器 / 重新编译之前,务必先读 [`macos/README.md`](macos/README.md) 的 TCC 章节** ——
那三条铁律是踩坑换来的,违反任何一条都会让整套授权静默失效。

---

# 🐳 大肥鱼

## Windows 版

| 操作 | 行为 |
|---|---|
| 双击 exe | 托盘出现鲸鱼;dsh 没开自动启动(隐藏运行,日志写 `dsh-tray.log`) |
| 左键 / 双击鲸鱼 | 唤起 DSH Web(通过配套浏览器扩展切换后台标签,**不新开页**) |
| 右键 → 开启/关闭大肥鱼 | 动态切换,状态每 2 秒自动刷新 |
| 右键 → 重启服务 | 仅运行时显示;停旧服务 → 等端口释放 → 隐藏重启 |
| 右键 → 充值 | 在 Edge 中打开 `https://platform.deepseek.com/usage` |
| 右键 → 退出 | 先关 dsh 服务,再退出程序 |

### 技术要点(Windows)

- **独立进程**:不依赖 dsh;强杀鲸鱼不影响 dsh,反之亦然
- **唤起 Web 三层方案**:① 窗口标题匹配(前台标签)② 浏览器扩展唤醒后台标签(推荐)③ 兜底新开
- **扩展通信**:本地端口 `9335`(鲸鱼发信号 → 扩展轮询 → `chrome.tabs.update` + `windows.update(state:'normal')`)
- **DPI**:PerMonitorV2 感知 + 系统菜单字体(`app.manifest`)
- **句柄安全**:监听 socket 标记不可继承(防止 dsh 子进程占用端口),端口被占时 20s 自愈重试
- **单实例**:互斥锁防止重复运行

### 构建(Windows)

```bat
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /target:winexe /out:大肥鱼.exe /win32icon:whale.ico /win32manifest:app.manifest /codepage:65001 /r:System.dll /r:System.Drawing.dll /r:System.Windows.Forms.dll /r:UIAutomationClient.dll /r:UIAutomationTypes.dll WhaleTray.cs
```

### 扩展安装(一次性)

1. `edge://extensions` → 打开「开发人员模式」
2. 「加载解压缩的扩展」→ 选择 `extension/` 目录
3. 以后点鲸鱼即可静默切换 DSH 标签

## macOS 版

Swift + Cocoa 的 `NSStatusItem` 应用。菜单栏右侧一只鲸鱼,**左键切标签、右键弹菜单**
(状态 · 开启/关闭 · 重启 · 打开网页 · 充值 · 退出),运行中彩色 / 停止时半透明。

```sh
cd macos && zsh build.sh     # 编译并安装到 ~/Desktop/大肥鱼.app
```

细节(图标合成、左右键分离原理、AppleScript 的坑、**以及必读的 TCC 权限章节**)
见 [`macos/README.md`](macos/README.md)。

---

# 🦞 OpenClaw 龙虾(macOS)

OpenClaw 网关的一键开关。比大肥鱼简单:**左键开 Control UI,右键只有「开启网关/退出」两项**。

- 网关走 **launchd**,启动天然静默无窗口
- 左键读配置里的 token 拼 URL,**Control UI 免验证直接进**
- **退出会一并停网关**
- 图标是 OpenClaw 官方矢量吉祥物(从它自己的 npm 包里取出来栅格化的)

```sh
cd openclaw && zsh build.sh          # 编译并安装到 ~/Desktop/OpenClaw.app
cd openclaw && zsh make_assets.sh    # 升级 OpenClaw 后刷新图标素材
```

细节见 [`openclaw/README.md`](openclaw/README.md)。

---

## 下载

`dist/` 里是打包好的 macOS 应用(解压即用):

| 文件 | 说明 |
|---|---|
| `dist/大肥鱼.app.zip` | macOS 菜单栏版大肥鱼 |
| `dist/OpenClaw.app.zip` | macOS 菜单栏版 OpenClaw 龙虾 |

> 因为是 ad-hoc 签名,首次打开会被 Gatekeeper 拦一下:右键 →「打开」,或
> `xattr -d com.apple.quarantine 大肥鱼.app`。
> ⚠️ **别再自己重新编译 `大肥鱼.app`** —— 会换 cdhash,让 TCC 授权全部失效。

## 目录

```
WhaleTray.cs      # Windows 主程序(C#, WinForms, .NET Framework 4.x)
app.manifest      # Windows DPI 感知清单
extension/        # Windows 配套浏览器扩展(唤醒后台 DSH 标签)
whale*.*          # Windows 图标(裁剪 + 缩放 + 白色提亮修复版)
macos/            # macOS 版大肥鱼(Swift)+ dsh-ctl.sh
openclaw/         # macOS 版 OpenClaw 龙虾(Swift)+ openclaw-ctl.sh
tools/            # 配套小工具(check-perms.sh 权限体检 / uictl 界面操作)
dist/             # 打包好的 macOS .app
```

## 🖼️ 图标出处

- **原始作者:月匠(B站)** —— 鲸鱼娘立绘由 B 站画师 **月匠** 绘制(原图见仓库内 `whale-source.png`,来自其 B 站动态)。
- 收录渠道:**dsh-whale-widget(DeepSeek 余额小鲸鱼挂件)插件**:
  [MeteorNOX/DeepSeek-Balance-Whale-Widget](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget)(MIT License,Copyright © 2026 MeteorNOX)
- 若月匠老师希望调整署名、更换或删除素材,请提 issue,我们立即处理。
- 本仓库对原图做了:裁剪(cut-out)、缩放到 16/32/48/256、小尺寸白色提亮修复,并打包为 `.ico`。
- **OpenClaw 龙虾**素材来自 OpenClaw 官方 npm 包内的 `dist/control-ui/favicon.svg`(矢量原图已收录在 `openclaw/assets/`)。

## 依赖

- DeepSeek Harness(dsh)
- Windows:系统已装 Edge / Chrome(唤起用)
- macOS:系统已装 Edge / Chrome(切标签用);dsh 侧见 `macos/README.md`
