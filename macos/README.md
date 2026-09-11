# 大肥鱼 · macOS 菜单栏版

Swift + Cocoa 的 `NSStatusItem` 应用 —— Windows 托盘版 `大肥鱼.exe` 的 macOS 对应物。

![菜单栏](https://img.shields.io/badge/形态-菜单栏常驻-blue) ![系统](https://img.shields.io/badge/macOS-13%2B-lightgrey)

## 与 Windows 版的区别

| | Windows (`WhaleTray.cs`) | macOS(本目录) |
|---|---|---|
| 形态 | 右下角**托盘**(WinForms) | 右上角**菜单栏**(`NSStatusItem`,`LSUIElement`,不占 Dock) |
| 启动服务 | 隐藏控制台窗口 | launchd / `nohup`,**天然静默无窗口** |
| 切标签页 | 本地 `9335` 端口 + **配套浏览器扩展**轮询 | 直接 **AppleScript** 操作 Edge/Chrome,**不需要扩展** |
| 状态刷新 | 每 2 秒 | 每 3 秒 TCP 探测 `127.0.0.1:3080` |
| 图标 | `.ico` | `.icns`(Dock/Finder)+ 18pt PNG @1x/@2x(菜单栏) |
| 退出 | 先关 dsh 服务再退出 | 同(`applicationWillTerminate` → `dsh-ctl.sh stop`) |
| 权限 | 基本不需要 | ⚠️ **要 TCC 授权,而且是本项目最大的坑** —— 见下 |

## 目录

```
main.swift         # 主程序(Swift / Cocoa)
icon_compose.swift # 合成 app 图标(深蓝渐变 + 鲸鱼)
icon_dump.swift    # 导出系统实际渲染的图标,用于检查
build.sh           # 编译 + 打包 + 安装到 ~/Desktop/大肥鱼.app
whale256.png       # 角色素材(透明背景)
dsh-ctl.sh         # 服务层:start/stop/restart/status/open/billing
README.md
```

> `dsh-ctl.sh` 默认要放在 `~/DeepSeekHarness/bin/`(app 里写死了这个路径)。
> 想放别处就改 `main.swift` 顶部的 `CTL` 常量。Windows 版是程序内直接管服务,Mac 版拆成了脚本。

## 构建

```sh
zsh build.sh
```

自包含:从**自身所在目录**读源码,编译后组装 `.app`,安装到 `~/Desktop/大肥鱼.app`,并刷新 Finder 图标。

### 可调参数(build.sh 顶部)

| 变量 | 默认 | 含义 |
|---|---|---|
| `ICON_SCALE` | 0.92 | 角色占画布的比例 |
| `ICON_OFFSET_Y` | 0.05 | 垂直位置(0 = 贴底) |
| `ICON_FADE` | 0.20 | 底部渐隐高度(溶掉原图的截断边) |

---

# ⚠️⚠️ TCC 权限:macOS 版最大的坑

**这一节是血的教训,改代码之前务必读完。**

macOS 会拦住"操作其他 App / 截屏 / 读受保护目录"的行为,必须在
**系统设置 → 隐私与安全性** 里授权。本应用(app 拉起的 dsh 进程)需要:

| 权限 | 用途 |
|---|---|
| **屏幕录制** | 截图 |
| **辅助功能** | 合成鼠标/键盘、读其他 App 的 UI |
| **完全磁盘访问** | 读受保护路径、删受保护的容器 |
| **自动化(Apple Events)** | 控制 Edge / Finder —— **"切标签页"靠它**,首次会弹窗 |

## 铁律一:DSH 必须由这个 app 启动

TCC 判定权限归属时看的是 **responsible process**(谁拉起的进程链),不是可执行文件本身。
所以 `~/Desktop/大肥鱼.app` 拉起的 dsh 才有权限;**在终端里 `dsh-ctl.sh start` 起的、或别的 app 起的,dsh 一样能跑,但四条权限全灭**。

## 铁律二:绝对不要重新编译这个 app

它是 **ad-hoc 签名**(没有 Apple 开发者证书),TCC 里存的"代码签名要求"就是**一个裸 cdhash**:

```
TCC 存的要求:  cdhash H"3790246aff4d65e7c1f4a65464925fa73bb31196"
大肥鱼.app 的:  CDHash   3790246aff4d65e7c1f4a65464925fa73bb31196
```

**重建 = 换 cdhash = 三条授权当场全废**,只能去系统设置里删掉重加。
要加功能,先想清楚代价,或者把新功能做进不需要授权的程序里。

## 铁律三:别让同名同 bundle id 的旧版本存在

曾经把旧的 AppleScript 版大肥鱼留在 `old-launcher/`,`CFBundleIdentifier` 和新版**一模一样**(`local.dsh.whale.menubar`)。

后果是连环的:
1. 从 Spotlight 打开**旧版** → 它拉起 dsh → responsible 变成旧 app → **所有权限一起被拒**
   日志:`Failed to match existing code requirement for subject local.dsh.whale.menubar`
2. 在系统设置里点 `+` 加"大肥鱼"时,加进去的也可能是**旧版**
   日志:`static code for: identifier local.dsh.whale.menubar ... at .../old-launcher/...`

**授权时务必从桌面拖 `大肥鱼.app`,不要用 Spotlight 搜索。**

## 排查手段

```sh
# 谁在 responsible 位置、哪条 requirement 没匹配上
log show --last 10m --predicate 'subsystem == "com.apple.TCC"' --style compact | grep -i "match existing"

# 直接看授权记录(需要完全磁盘访问;系统库含 录制/辅助功能/FDA,用户库含 自动化)
sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" \
  "select service,client,auth_value from access where client like '%whale%';"

# 解出 TCC 存的签名要求,和 app 当前 cdhash 对照
sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" \
  "select writefile('/tmp/r.bin',csreq) from access where client='local.dsh.whale.menubar' and service='kTCCServiceSystemPolicyAllFiles';"
csreq -r /tmp/r.bin -t
codesign -dv --verbose=4 ~/Desktop/大肥鱼.app 2>&1 | grep CDHash
```

---

# 编译 / 图标 / 交互的三个坑

### 1. 编译必须显式指定 SDK

CLT 的 `swiftc` 可能是 6.3.3,而 `xcrun` 默认选中 `MacOSX27.0.sdk`(Swift 6.4 构建),直接编译会报:

```
error: failed to build module 'Swift'; this SDK is not supported by the compiler
```

必须显式指定匹配的 SDK(`build.sh` 已自动挑 `MacOSX26*.sdk` 并避开 27):

```sh
swiftc -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ...
```

**clang 同理**:27.0 的 `.tbd` 含 `arm64e.x1-macos` 架构,clang 21.0 不认识。

### 2. 别用 `SetFile -a C`

它标记"此 bundle 有自定义图标"。没有配套资源时,Finder 会**忽略 `CFBundleIconFile`** 画成通用图标。
(`GetFileInfo` 打印的 `avbstclinmedz` 是固定模板文本,空文件夹也一模一样,别当真。)

### 3. `cp -R src dst` 在 dst 已存在时会嵌套成 `dst/src`

复制前先 `rm -rf dst`。

## 图标是怎么做的

macOS 26 会把图标内容装进圆角方块。源素材 `whale256.png` 是**透明背景**的头肩特写,
直接当图标用,系统会补一层灰色默认背景。

`icon_compose.swift`:
1. 铺深蓝渐变(`#5B78C7` → `#273366`)作背景
2. 叠上角色图,按 `ICON_SCALE` / `ICON_OFFSET_Y` 定位
3. 底部叠一条渐隐,把源图底边的生硬截断溶进背景

`icon_dump.swift` 可导出**系统实际渲染出来**的图标做检查:

```sh
swiftc -sdk <sdk> -o /tmp/icon_dump icon_dump.swift -framework AppKit
/tmp/icon_dump ~/Desktop/大肥鱼.app /tmp/preview.png
```

## 行为

- 鲸鱼常驻菜单栏右侧(`LSUIElement=true`,不占 Dock)
- **左键 → 切到已打开的 DSH 标签**(没开则启动服务并新开);**右键(或 ⌃+左键)→ 弹菜单**
- 菜单:状态 · 开启-关闭 · 重启 · 打开网页 · 充值 · 退出
- **退出时一并关闭 DSH 网关**,不留孤儿服务占着 3080
- 运行中图标彩色 / 停止时半透明(alpha 0.35),一眼看出状态

### 左右键分离是怎么做的

`NSStatusItem` 默认行为是:**只要挂了 `menu`,左右键就都弹菜单**。所以关键三步:

1. **启动时不设 `statusItem.menu`**(保持 `nil`)
2. `button.sendAction(on: [.leftMouseUp, .rightMouseUp])` —— 否则右键收不到
3. action 里判事件类型:
   - 右键 → 临时 `statusItem.menu = menu` + `performClick(nil)`(让 AppKit 原生定位菜单),弹完立刻置回 `nil`
   - 左键 → `openWeb()`

**为什么用 `performClick` 而不是 `menu.popUp(positioning:at:in:)`**:`popUp` 要自己算坐标,
status bar 按钮的坐标系容易算错(菜单会飘);`performClick` 由系统定位,永远对。

菜单内容靠 `NSMenuDelegate.menuNeedsUpdate(_:)` 每次弹出前重建,状态永远实时;
**不要**在 action 里手动再调一次 `menuNeedsUpdate`,否则会把正在显示的菜单清空。

### 「打开网页」为什么不需要浏览器扩展

Windows 版靠 9335 端口轮询服务 + 配套扩展实现"切到已开的标签而不是新开"。

**macOS 不需要**:Chromium 系浏览器把标签页暴露给 AppleScript。本应用内置
`raiseExistingDshTab()`:用 osascript 遍历 Edge 的窗口/标签,找到 `http://127.0.0.1:3080` 就切过去并激活窗口;
找不到(或 Edge 没开)才回退到 `NSWorkspace.open` 新开。

写这段 AppleScript 有两个坑:
1. **必须用数字索引**(`window i` / `tab j of window i`)。写成 `repeat with t in tabs of w` 拿到的是**引用**,
   再取 `index of t` 会报 `不能将 ... 转换为 Unicode text`(-1700 / -10006)。
2. 首次运行会弹**「大肥鱼 想要控制 Microsoft Edge」**的自动化授权,需要点允许;
   拒绝的话会静默回退到新开标签,功能不中断。

## 开机自启

默认**不启用**(手动启动)。要开就建个 LaunchAgent:

```
~/Library/LaunchAgents/local.dsh.whale.menubar.plist
  ProgramArguments -> /Users/<你>/Desktop/大肥鱼.app/Contents/MacOS/WhaleLauncher
  RunAtLoad = true
```
