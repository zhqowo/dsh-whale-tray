# 🐳 大肥鱼 · DeepSeek Harness 启动器

[English](README.en.md) | 中文

DSH(DeepSeek Harness)的**一键开关** —— Windows 是右下角托盘,macOS 是右上角菜单栏。
**独立于 dsh 进程**,类似 Steam 的启动器。

> 🦞 **找 OpenClaw 龙虾?** 那个已经拆到独立仓库了:
> **[zhqowo/openclaw-menubar](https://github.com/zhqowo/openclaw-menubar)** —— 两者受众不同,
> 分开之后各自能被搜到、各自独立发版。

## 我该用哪个

| 平台 | 程序 | 形态 | 源码 |
|---|---|---|---|
| **Windows** | `大肥鱼.exe` | 右下角**托盘** | [`WhaleTray.cs`](WhaleTray.cs) |
| **macOS** | `大肥鱼.app` | 右上角**菜单栏** | [`macos/`](macos/) |

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
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /target:winexe /out:大肥鱼.exe /win32icon:whale.ico /win32manifest:app.manifest /codepage:65001 /r:System.dll /r:System.Drawing.dll /r:System.Windows.Forms.dll /r:System.Web.Extensions.dll /r:UIAutomationClient.dll /r:UIAutomationTypes.dll WhaleTray.cs
```

### 扩展安装(一次性)

1. `edge://extensions` → 打开「开发人员模式」
2. 「加载解压缩的扩展」→ 选择 `extension/` 目录
3. 以后点鲸鱼即可静默切换 DSH 标签

## macOS 版

Swift + Cocoa 的 `NSStatusItem` 应用。菜单栏右侧一只鲸鱼,**左键切标签、右键弹菜单**
(状态 · 开启/关闭 · 重启 · 打开网页 · 充值 · 退出),运行中彩色 / 停止时半透明。

### 一键安装(推荐)

```sh
curl -fsSL https://raw.githubusercontent.com/zhqowo/dsh-whale-tray/main/macos/install.sh | zsh
```

它会自动找到你的 dsh、把 app 装进 `/Applications`、装好服务脚本 `dsh-ctl.sh`、写好配置,最后跑一遍体检。
dsh 不在 `~/DeepSeekHarness`?加 `--dir`;端口不是 3080?加 `--port`;不用 Edge?加 `--browser "Google Chrome"`。

```sh
# 从仓库本地跑(需要先 git clone)
zsh macos/install.sh --dir ~/code/DeepSeekHarness --port 3100 --browser "Google Chrome"
```

**只要你想要"一键启动 + 打开网页",这就完了** —— 唯一需要点的是第一次点「打开网页」时弹的
「大肥鱼 想要控制 Microsoft Edge」,点允许。

### 自己编译(改代码时)

```sh
WHALE_APP_OUT=/tmp/staging/大肥鱼.app zsh macos/build.sh   # 暂存,不动你桌面上那份
```

> ⚠️ `zsh macos/build.sh` 不加 `WHALE_APP_OUT` 会**覆盖并重建** `~/Desktop/大肥鱼.app`——
> 那会换 cdhash,让 TCC 里存的授权全部失效。改代码时一律用暂存模式。

细节(配置项、`doctor` 体检、`--print-url` 调试、**为什么不能像插件那样一键装**、
**功能阉割的四档做法**、图标合成、左右键分离原理、AppleScript 的坑、**必读的 TCC 权限章节**)
见 **[`macos/README.md`](macos/README.md)**。

---

## ⚙️ 配置(可选,两个平台都支持)

**不配置也能用** —— 默认值就是给标准 DeepSeek + dsh 环境准备的。

<details>
<summary><b>「充值」写死指向 DeepSeek?我怎么改成别的?</b></summary>

菜单里的**充值**默认打开 `https://platform.deepseek.com/usage`。
但本启动器只管开关 dsh 服务,跟模型供应商无关 —— 你完全可以用别家的模型。

放一个 JSON 配置文件就能改,**不用重新编译**:

<table>
<tr><th>平台</th><th>路径</th></tr>
<tr><td>macOS</td><td><code>~/.config/dsh-whale-tray/config.json</code></td></tr>
<tr><td>Windows</td><td><code>%APPDATA%\dsh-whale-tray\config.json</code></td></tr>
</table>

> 也可以用环境变量 `DSH_WHALE_TRAY_CONFIG` 指定任意路径(两平台通用)。

```jsonc
{
  // 充值/账单要打开的页面
  "billingUrl":   "https://your-provider.example/billing",
  // 菜单里那一项显示什么字(默认「充值」)
  "billingLabel": "账单",

  // 仅 Windows:你的 dsh 装在哪儿
  // 留空则自动探测 D:\DeepSeekHarness,再退回 %USERPROFILE%\DeepSeekHarness
  "dshHome":      "C:\\DeepSeekHarness",

  // 仅 macOS:你的 dsh 装在哪儿 / 端口 / 用哪个浏览器
  // 端口和浏览器改了这一处就行,菜单栏 app 和 dsh-ctl.sh 读的是同一个文件
  "dshDir":       "~/DeepSeekHarness",
  "port":         3080,
  "browser":      "Microsoft Edge"
}
```

| 键 | 默认值 | 作用 |
|---|---|---|
| `billingUrl` | `https://platform.deepseek.com/usage` | 充值项打开的网址 |
| `billingLabel` | `充值` | 充值项的显示文字 |
| `dshHome` | 自动探测 | **仅 Windows**:dsh 安装根目录 |
| `dshDir` | `~/DeepSeekHarness` | **仅 macOS**:dsh 安装根目录 |
| `port` | `3080` | **仅 macOS**:DSH 端口 |
| `browser` | `Microsoft Edge` | **仅 macOS**:AppleScript 控制哪个浏览器 |
| `logPath` | `<dshDir>/dsh-web.log` | **仅 macOS**:从这个日志捞 `?token=`(0.1.7+ 必需) |
| `workdir` | `<dshDir>/projects` | **仅 macOS**:启动 dsh 时的 cwd |
| `ctlPath` | `<dshDir>/bin/dsh-ctl.sh` | **仅 macOS**:服务脚本位置,一般不用写 |

- **所有键都是可选的**,给几个生效几个
- 文件不存在 / JSON 写错 / 类型不对 → **静默回退默认值**,绝不让托盘或菜单栏起不来
- 命令行 `macos/dsh-ctl.sh billing` 读同一个文件
- macOS 版 `dsh-ctl.sh` 还认环境变量(优先级高于文件):
  `DSH_DIR` `DSH_PORT` `DSH_LOG` `DSH_BIN` `DSH_WORKDIR` `DSH_BROWSER` `DSH_BILLING_URL`
- 不支持 JSON 注释 —— 上面只是为了标注才写成 `jsonc`
</details>

---

# 🦞 OpenClaw 龙虾 → 已拆分为独立仓库

OpenClaw 网关的菜单栏开关**曾经**和本仓库放在一起,现已迁到:

### 👉 **[zhqowo/openclaw-menubar](https://github.com/zhqowo/openclaw-menubar)**

它跟大肥鱼是**两个受众**:大肥鱼伺候 DSH 用户,龙虾伺候 OpenClaw 用户。
合在一起会让两边都搜不到对方的关键词,所以拆了。

- 源码、构建脚本、图标素材、Release 全在新仓库
- 原 `openclaw/` 目录已从本仓库移除(内容与 Git 记录完整保留在新仓库)

---

## 作为 DSH 插件安装(只登记清单,不装 app)

本仓库声明了 `dsh.bundle` manifest,所以能被 `dsh plugin add` 认出来:

```sh
dsh plugin --profile web add github:zhqowo/dsh-whale-tray
```

> ⚠️ **这条命令不会把菜单栏 app 装到你的 Mac 上。** 它只是把仓库登记进 profile,
> 让插件市场 / `find_dsh_plugin` 能搜到它。
> 装不了的原因有四条:① 桌面 app 没法走 npm 分发 ② ad-hoc 签名会被 Gatekeeper 拦
> ③ TCC 授权没法程序化 ④ 每台机器路径/端口/浏览器都不同。
> 逐条解释 + 你需要在本机做什么 + 只要一部分功能时怎么阉割,全在
> [`macos/README.md`](macos/README.md#为什么不能像插件一样一键装)。
>
> **想真正装好,用上面「一键安装」那条 curl。**

## 下载

**推荐直接用 [Releases](https://github.com/zhqowo/dsh-whale-tray/releases/latest),
或者上面那条一键安装命令。**

| 位置 | 文件 | 说明 |
|---|---|---|
| Releases | `DaFeiYu.app.zip` | macOS 菜单栏版;`install.sh` 就拉这个稳定 URL |
| `dist/` | `大肥鱼.app.zip` | 旧的历史存档,保留不动 |

> 🦞 OpenClaw 龙虾的下载在新仓库:
> [openclaw-menubar/releases](https://github.com/zhqowo/openclaw-menubar/releases/latest)


> 因为是 ad-hoc 签名,首次打开会被 Gatekeeper 拦一下:右键 →「打开」,或
> `xattr -dr com.apple.quarantine /Applications/大肥鱼.app`。
> ⚠️ **别再自己重新编译 `大肥鱼.app`** —— 会换 cdhash,让 TCC 授权全部失效。
> 升级到新版同理:截图/点界面报权限错时,把大肥鱼从隐私列表里删掉重新添加一次就好。

## 目录

```
WhaleTray.cs      # Windows 主程序(C#, WinForms, .NET Framework 4.x)
app.manifest      # Windows DPI 感知清单
extension/        # Windows 配套浏览器扩展(唤醒后台 DSH 标签)
whale*.*          # Windows 图标(裁剪 + 缩放 + 白色提亮修复版)
macos/            # macOS 版大肥鱼(Swift)+ install.sh + dsh-ctl.sh
tools/            # 配套小工具(check-perms.sh 权限体检 / uictl 界面操作)
dist/             # 打包好的 macOS .app
package.json      # dsh 插件清单(声明 dsh.bundle,供 dsh plugin add 安装)
cordis.patch.yml  # 上面那个 manifest 指向的 patch 文件
```

> 🦞 OpenClaw 龙虾已拆到 [zhqowo/openclaw-menubar](https://github.com/zhqowo/openclaw-menubar)。

## 🖼️ 图标出处

**鲸鱼娘立绘不是我画的**,出处如下,两个平台的图标都从这张原图加工而来。

- **原始作者:月匠(B站)** —— 鲸鱼娘立绘由 B 站画师 **月匠** 绘制
  (原图见仓库内 [`whale-source.png`](whale-source.png),来自其 B 站动态)
- **收录渠道**:**dsh-whale-widget(DeepSeek 余额小鲸鱼挂件)插件** ——
  [MeteorNOX/DeepSeek-Balance-Whale-Widget](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget)
  (MIT License, Copyright © 2026 MeteorNOX)
- 若月匠老师希望调整署名、更换或删除素材,请提 issue,**我们立即处理**

本仓库对原图**没有做美术改动**,只做了机械处理:

| 文件 | 平台 | 怎么来的 |
|---|---|---|
| `whale.ico` | Windows | 原图裁剪 → 缩放到 16/32/48/256 → 打包 ico |
| `whale16/32/48/256.png` | Windows | 同上,各尺寸单独文件 |
| `macos/whale256.png` | macOS | 原图缩小到 256(构建素材的起点) |
| 菜单栏 `whale.png` / `whale@2x.png` | macOS | 上者 `sips -z` 缩成 **22px / 44px** |
| app 图标 `AppIcon.icns` | macOS | 上者叠在渐变卡片上(`icon_compose.swift`)后转 icns |

> **小尺寸做了白色提亮修复** —— 原图缩到 16px 后线条会糊成一团暗色,提亮后才看得清。
>
> macOS 那 22px 图标还有个坑:`NSImage(contentsOfFile:)` **不会**自动加载 `@2x` 兄弟文件,
> 只塞一个在 Retina 上会发虚,所以构建脚本两个尺寸都塞。
>
> 完整第三方素材声明见 [NOTICE](NOTICE)。


## 依赖

- DeepSeek Harness(dsh)
- Windows:系统已装 Edge / Chrome(唤起用)
- macOS:系统已装 Edge / Chrome(切标签用);dsh 侧见 `macos/README.md`

## 许可

[MIT](LICENSE) © 2026 zhqowo —— 随便用、改、商用,保留版权声明即可。

⚠️ 图标/素材除外:**鲸鱼素材版权属原画师月匠(B站)**,收录链路与署名要求见上面「图标出处」一节。
二次分发请一并保留这个署名。
