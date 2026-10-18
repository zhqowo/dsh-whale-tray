# 大肥鱼 · macOS 菜单栏版

Swift + Cocoa 的 `NSStatusItem` 应用 —— Windows 托盘版 `大肥鱼.exe` 的 macOS 对应物。

![菜单栏](https://img.shields.io/badge/形态-菜单栏常驻-blue) ![系统](https://img.shields.io/badge/macOS-13%2B-lightgrey)

一句话:菜单栏养一条鲸鱼,**左键**切到你已经开着的 DSH 网页,**右键**是开 / 关 / 重启 / 充值 / 退出。

---

## 目录

```
main.swift         # 主程序(Swift / Cocoa)
install.sh         # 一键安装:找 dsh → 装 app → 装脚本 → 写配置
dsh-ctl.sh         # 服务层:start/stop/restart/status/pid/url/open/billing/doctor
icon_compose.swift # 合成 app 图标(深蓝渐变 + 鲸鱼)
icon_dump.swift    # 导出系统实际渲染的图标,用于检查
build.sh           # 编译 + 打包(作者用;也能被 install.sh --build 调用)
whale256.png       # 角色素材(透明背景)
README.md
```

> 🔧 **想照着自己做一个 Mac 菜单栏 app?** 编译 / 签名 / TCC / 分发的 24 个坑和验证命令
> 单独抽成了一份通用文档:[`../docs/BUILDING-MACOS-APP.md`](../docs/BUILDING-MACOS-APP.md)。

---

## 一键安装(给别人用)

```sh
curl -fsSL https://raw.githubusercontent.com/zhqowo/dsh-whale-tray/main/macos/install.sh | zsh
```

它做四件事,每一步都打印出来,任何一步失败都会停下并说明原因:

1. 找到你的 dsh 装在哪(`--dir` 指定,或自动从 `~/DeepSeekHarness` / `PATH` 猜)
2. 装菜单栏 app 到 `/Applications`(`/Applications` 不可写时退回 `~/Applications`)
3. 装 `dsh-ctl.sh` 到 `<你的 dsh 目录>/bin/`
4. 写配置 `~/.config/dsh-whale-tray/config.json`,最后跑一遍体检

常用选项:

| 选项 | 作用 |
|---|---|
| `--dir <path>` | dsh 安装根目录,例如 `~/code/DeepSeekHarness` |
| `--dest <dir>` | app 装到哪,默认 `/Applications` |
| `--port <n>` | DSH 端口,默认 `3080` |
| `--browser <name>` | 用哪个浏览器,默认 `Microsoft Edge`,可写 `Google Chrome` / `Safari` |
| `--build` | 本机编译(要先 `git clone`,需要 Xcode Command Line Tools),不走 Release 下载 |
| `--no-app` | 只装服务脚本 + 配置,**不装 app**(见下面"阉割档位 0") |
| `--no-ctl` | 不装 / 不覆盖 `dsh-ctl.sh` |
| `--yes` | 不提问 |

不想跑脚本也能手动装:去 [Releases](../../releases/latest) 下 `DaFeiYu.app.zip`,解压后把 `大肥鱼.app` 拖进 `/Applications`;
再把 `dsh-ctl.sh` 复制到 `<你的 dsh 目录>/bin/` 并 `chmod +x`;最后手写 `~/.config/dsh-whale-tray/config.json`(键见下面"配置")。

---

## 为什么不能"像插件一样"一键装

DSH 的插件装法很顺:`dsh plugin --profile web add <包名>`。但这套机制**装不了菜单栏 app**,卡在四件事上,不是没写好,是机制上做不到:

**① npm 只能分发 JS,装不了 `.app`。**
DSH 的插件分发单元是 npm 包;`dsh plugin add` 把包装进 profile,再读包里的 `cordis.patch.yml` 决定往哪个槽插一段 JS。
一个 `.app` 是 Mach-O 二进制 + Info.plist + 代码签名组成的 bundle——npm 没有"装它"这个动作,DSH 也没有。
所以本仓库的 `cordis.patch.yml` 内容是**空数组 `[]`**:它的唯一作用是让 `dsh plugin --profile web add github:zhqowo/dsh-whale-tray` 这条命令能成功、让插件市场能搜到它,让 `find_dsh_plugin` 能给你指出仓库位置。
**能 add 上 ≠ app 装好了。**

**② 没签名、没公证,Gatekeeper 会拦。**
本项目用 ad-hoc 签名(`codesign --sign -`),在 Apple 眼里等于"未签名"。从网络下载的 `.app` 首次打开会被拦成「无法验证开发者,无法打开」。
`install.sh` 里的 `xattr -dr com.apple.quarantine` 等于替你点了「右键 → 打开」,**但这一步必须由用户主动执行**(脚本本身也是用户主动跑的,所以可以)。任何"我来帮你自动装好"的说法都绕不过它——除非去申请 Apple 开发者证书并公证(`notarytool`),那是一年 99 美元 + 每次发版要提交审核。

**③ TCC 授权没法程序化,而且绑在 cdhash 上。**
屏幕录制、辅助功能、完全磁盘访问这三条只有用户能在「系统设置 → 隐私与安全性」里手动加,或者接受首次运行时弹窗。
更麻烦的是:ad-hoc 签名没有稳定身份(没有 Team ID),TCC 只能把授权记在**某一次构建的 cdhash** 上——**换一个版本二进制就变,授权就要重来**。
这是 macOS 的设计,不是能绕过去的东西。

**④ 没有"标准 DSH 安装位置"。**
dsh 可能装在 `~/DeepSeekHarness`,可能装在 `~/code/dsh`,也可能全局;端口不一定是 3080;浏览器不一定是 Edge。
旧版把这些**写死在 Swift 里**(`~/DeepSeekHarness/bin/dsh-ctl.sh`、`3080`、`"Microsoft Edge"`),别人装上一跑就是 401 白屏或者"点了没反应"。
2.3 起全部改成读配置,所以才有"直接拉取安装"这回事。

一句话总结:**一条命令能自动化到"文件都就位";剩下 Gatekeeper 放行和 TCC 授权这两下,只能由用户点。**

---

## 别人的机器上要做什么,才能和你完全一样

### 必须做的(3 步)

1. **有 dsh**,且知道它在哪(`node_modules/.bin/dsh` 存在即可)。0.1.7 以下也能跑,只是不需要 token 那套逻辑。
2. **跑一次 `install.sh`**(上面那条 curl)。
3. **打开 `/Applications/大肥鱼.app`**,菜单栏出现鲸鱼。第一次点「打开网页」会弹
   「大肥鱼 想要控制 Microsoft Edge」→ **点允许**(允许之后才会"切到已存在的标签",否则每次新开)。

到这一步,「一键启动 + 打开网页 + 开关重启 + 充值 + 退出」就全好了。

### 想和你**完全**一样(包括让 DSH 能截图 / 点界面 / 读受保护目录)

4. **系统设置 → 隐私与安全性**,把 `/Applications/大肥鱼.app` 加进这三处:
   屏幕录制、辅助功能、完全磁盘访问。
5. **让 DSH 由大肥鱼启动**(菜单栏点它 → 开启服务),不要在终端里 `dsh-ctl.sh start`。
   TCC 看的是 **responsible process**(谁拉起的进程链),终端拉起的 dsh 一样能跑,但那三条权限全灭。
6. (可选)开机自启,见文末。

### ⚠️ 升级版本的代价

第 4 步的授权绑在**二进制**上。你下次发新版、别人换了新 `.app`,**cdhash 变了,三条授权就失效**,要回系统设置里删掉重加。
所以给别人的发布说明里最好写一句:"升级后如果截图/点界面报权限错,把大肥鱼从隐私列表里删掉重新添加一次。"

---

## 功能阉割:四档

不是所有人都想要"能替 DSH 点鼠标"。按需要往下砍,砍一档少一批权限:

| 档位 | 装什么 | 需要的 TCC 权限 | 能干什么 | 少什么 |
|---|---|---|---|---|
| **0 纯启动器** | 只装脚本:`install.sh --no-app` | **0 条** | `dsh-ctl.sh start/stop/restart/open`;可以挂到「快捷指令」/ Raycast / 一个 alias | 没有菜单栏图标 |
| **1 菜单栏开关** | 装 app,但**拒绝**自动化授权 | **0 条** | 菜单栏鲸鱼、开/关/重启/打开网页/充值/退出、状态色、缺脚本时告警 | 点「打开网页」每次**新开**标签,不会切到已打开的那个 |
| **2 完整版(默认)** | app + **允许**自动化 | **自动化 1 条** | 上面全部 + 切到已存在的 DSH 标签,不堆重复标签 | — |
| **3 全功能** | 再用 computer-use 之类的工具 | **+ 屏幕录制 / 辅助功能 / 完全磁盘访问** | DSH 能截图、点界面、读写受保护目录 | — |

具体怎么做:

- **档位 0**:
  ```sh
  curl -fsSL .../install.sh | zsh -s -- --no-app
  # 之后就把 <dshDir>/bin/dsh-ctl.sh 当命令用:
  #   alias dsh-web='~/DeepSeekHarness/bin/dsh-ctl.sh open'
  ```
  连脚本都不想要的话,最土的办法已经够用:
  ```sh
  cd ~/DeepSeekHarness && node_modules/.bin/dsh web --port 3080 --no-open
  ```
  (缺点是 0.1.7 以后裸开 `127.0.0.1:3080` 是 **401**,得从日志里捞 `?token=...`——`dsh-ctl.sh open` 自动干这件事。)

- **档位 1**: 正常装,第一次弹「想要控制 X」时点**拒绝**。功能不中断,只是不再切标签。

- **档位 2**: 就是默认。点允许。

- **档位 3**: 把 app 加进那三条权限,并且**用 app 启动 dsh**。不需要就千万别加——加了以后每次改代码重建 app 都要重新授权。

---

## 配置(可选)

所有机器相关的值集中在一个文件,不写就全用默认:

```
~/.config/dsh-whale-tray/config.json     # 或 $DSH_WHALE_TRAY_CONFIG
```

```json
{
  "dshDir":     "~/DeepSeekHarness",
  "port":       3080,
  "browser":    "Microsoft Edge",
  "billingUrl": "https://platform.deepseek.com/usage"
}
```

| 键 | 默认 | 说明 |
|---|---|---|
| `dshDir` | `~/DeepSeekHarness` | dsh 安装根目录(里面要有 `node_modules/.bin/dsh`) |
| `ctlPath` | `<dshDir>/bin/dsh-ctl.sh` | 服务脚本位置,一般不用写 |
| `port` | `3080` | DSH 端口 |
| `logPath` | `<dshDir>/dsh-web.log` | 从这个日志里捞 `?token=` |
| `workdir` | `<dshDir>/projects` | 启动 dsh 时的 cwd |
| `browser` | `Microsoft Edge` | AppleScript 控制哪个浏览器(`Google Chrome` / `Safari` 也行) |
| `billingUrl` | `https://platform.deepseek.com/usage` | 菜单「充值」打开哪个页面 |

`dsh-ctl.sh` 还认环境变量,优先级高于配置文件:
`DSH_DIR` `DSH_PORT` `DSH_LOG` `DSH_BIN` `DSH_WORKDIR` `DSH_BROWSER` `DSH_BILLING_URL`

app 和脚本读**同一个**配置文件,所以改端口只改一处。
唯一要注意:`dshDir` 含空格也没问题(两边都做了引号转义)。

---

## 出问题先看这两条

```sh
# 1. 环境体检:哪一步没接上,它会直接说出来
~/DeepSeekHarness/bin/dsh-ctl.sh doctor

# 2. app 点「打开网页」到底会打开什么(以及 token 有没有取到)
/Applications/大肥鱼.app/Contents/MacOS/WhaleLauncher --print-url
```

`--print-url` 输出长这样,一眼看出是 `ctlPath` 没找到、端口配错、还是 token 没捞到:

```
ctl    : /Users/me/DeepSeekHarness/bin/dsh-ctl.sh  [found]
port   : 3080
browser: Microsoft Edge
url    : http://127.0.0.1:3080/?token=xxxxxxxx
```

常见症状对照:

| 症状 | 原因 |
|---|---|
| 点开是 **401 页面** | 日志里没有 token。`dsh-ctl.sh doctor` 看「日志」和「token」两行 |
| 菜单栏没有鲸鱼 | app 没启动,或同 bundle id 的旧副本在捣乱(见铁律三) |
| 菜单里写着 `⚠️ 缺少 .../dsh-ctl.sh` | 脚本没装到那个路径;改 `dshDir`,或重跑 `install.sh` |
| 点了没反应 / 白屏 | 端口不对;`lsof -nP -iTCP -sTCP:LISTEN` 看 dsh 实际听哪个端口 |
| 每次点都新开一个标签 | 自动化授权被拒了(铁律:允许「大肥鱼 想要控制 Edge」) |

---

## 与 Windows 版的区别

| | Windows (`WhaleTray.cs`) | macOS(本目录) |
|---|---|---|
| 形态 | 右下角**托盘**(WinForms) | 右上角**菜单栏**(`NSStatusItem`,`LSUIElement`,不占 Dock) |
| 启动服务 | 隐藏控制台窗口 | launchd / `nohup`,**天然静默无窗口** |
| 切标签页 | 本地 `9335` 端口 + **配套浏览器扩展**轮询 | 直接 **AppleScript** 操作 Edge/Chrome,**不需要扩展** |
| 状态刷新 | 每 2 秒 | 每 3 秒 TCP 探测 `127.0.0.1:<port>` |
| 图标 | `.ico` | `.icns`(Dock/Finder)+ 18pt PNG @1x/@2x(菜单栏) |
| 退出 | 先关 dsh 服务再退出 | 同(`applicationWillTerminate` → `dsh-ctl.sh stop`) |
| 权限 | 基本不需要 | ⚠️ **要 TCC 授权,而且是本项目最大的坑** —— 见下 |

> Windows 版目前**只有源码,没有编译好的产物**;Releases 里的两个包都是 macOS。

---

## 构建

```sh
zsh build.sh                                                   # 覆盖 ~/Desktop/大肥鱼.app 并启动它
WHALE_APP_OUT=/tmp/staging/大肥鱼.app zsh build.sh              # 暂存:不覆盖、不杀进程、不启动
```

**推荐永远用暂存模式**——见下面铁律二。自包含:从**自身所在目录**读源码,编译后组装 `.app`。

### 可调参数(build.sh 顶部)

| 变量 | 默认 | 含义 |
|---|---|---|
| `ICON_SCALE` | 0.92 | 角色占画布的比例 |
| `ICON_OFFSET_Y` | 0.05 | 垂直位置(0 = 贴底) |
| `ICON_FADE` | 0.20 | 底部渐隐高度(溶掉原图的截断边) |

---

# ⚠️⚠️ TCC 权限:macOS 版最大的坑

**下面三条是作者本机的血泪教训。自己机器上第一次装(档位 2)不需要理解这些,但如果你要改代码、要重建,务必读完。**

macOS 会拦住"操作其他 App / 截屏 / 读受保护目录"的行为,必须在
**系统设置 → 隐私与安全性** 里授权。本应用(以及它拉起的 dsh 进程)可能需要:

| 权限 | 用途 |
|---|---|
| **屏幕录制** | 截图 |
| **辅助功能** | 合成鼠标/键盘、读其他 App 的 UI |
| **完全磁盘访问** | 读受保护路径、删受保护的容器 |
| **自动化(Apple Events)** | 控制 Edge / Finder —— **"切标签页"靠它**,首次会弹窗 |

## 铁律一:想让 dsh 有权限,DSH 必须由这个 app 启动

TCC 判定权限归属时看的是 **responsible process**(谁拉起的进程链),不是可执行文件本身。
所以 app 拉起的 dsh 才有权限;**在终端里 `dsh-ctl.sh start` 起的、或别的 app 起的,dsh 一样能跑,但四条权限全灭**。

## 铁律二:别在原地反复重建 app

它是 **ad-hoc 签名**(没有 Apple 开发者证书),TCC 里存的"代码签名要求"就是**一个裸 cdhash**:

```
TCC 存的要求:  cdhash H"3790246aff4d65e7c1f4a65464925fa73bb31196"
大肥鱼.app 的:  CDHash   3790246aff4d65e7c1f4a65464925fa73bb31196
```

**重建 = 换 cdhash = 三条授权当场全废**,只能去系统设置里删掉重加。
所以要重建时用 `WHALE_APP_OUT=...` 装到别处、改完验证好再一次性上线;别在桌面那份上反复编译。

## 铁律三:别让同名同 bundle id 的旧版本存在

曾经把旧的 AppleScript 版大肥鱼留在 `old-launcher/`,`CFBundleIdentifier` 和新版**一模一样**(`local.dsh.whale.menubar`)。

后果是连环的:

1. 从 Spotlight 打开**旧版** → 它拉起 dsh → responsible 变成旧 app → **所有权限一起被拒**
   日志:`Failed to match existing code requirement for subject local.dsh.whale.menubar`
2. 在系统设置里点 `+` 加"大肥鱼"时,加进去的也可能是**旧版**
   日志:`static code for: identifier local.dsh.whale.menubar ... at .../old-launcher/...`

**授权时务必从 Finder 里拖 `大肥鱼.app`,不要用 Spotlight 搜索。**

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
codesign -dv --verbose=4 /Applications/大肥鱼.app 2>&1 | grep CDHash
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
/tmp/icon_dump /Applications/大肥鱼.app /tmp/preview.png
```

---

## 行为

- 鲸鱼常驻菜单栏右侧(`LSUIElement=true`,不占 Dock)
- **左键 → 切到已打开的 DSH 标签**(没开则启动服务并新开);**右键(或 ⌃+左键)→ 弹菜单**
- 菜单:状态 · 开启-关闭 · 重启 · 打开网页 · 充值 · 退出
- **退出时一并关闭 DSH 网关**,不留孤儿服务占着端口
- 运行中图标彩色 / 停止时半透明(alpha 0.35),一眼看出状态
- `dsh-ctl.sh` 找不到时,tooltip 和菜单里都会直接显示**缺哪个文件**、该改哪个配置

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
`raiseExistingDshTab()`:用 osascript 遍历浏览器的窗口/标签,找到 `http://127.0.0.1:<port>` 开头的那页就切过去并激活窗口;
找不到(或浏览器没开)才回退到 `NSWorkspace.open` 新开。

写这段 AppleScript 有两个坑:

1. **必须用数字索引**(`window i` / `tab j of window i`)。写成 `repeat with t in tabs of w` 拿到的是**引用**,
   再取 `index of t` 会报 `不能将 ... 转换为 Unicode text`(-1700 / -10006)。
2. 首次运行会弹**「大肥鱼 想要控制 Microsoft Edge」**的自动化授权,需要点允许;
   拒绝的话会静默回退到新开标签,功能不中断。

### 0.1.7 之后的 token

dsh **0.1.7** 起加了 Web 认证:裸开 `http://127.0.0.1:3080/` 一律 **401**,必须带 `?token=...`。
第一访问会用 token 种一个 **30 天** cookie,之后裸 URL 才重新能用。

所以"打开网页"不再是自己拼 URL,而是走 `dsh-ctl.sh url`——它从 dsh 日志里 grep 最新的
`token=...`,拼成完整地址。拿不到就回退裸 URL(兼容 0.1.7 以前)。
这也是为什么 `dsh-ctl.sh` 必须知道 `logPath`:拿不到日志就拿不到 token。

---

## 开机自启

默认**不启用**(手动启动)。要开就建个 LaunchAgent:

```
~/Library/LaunchAgents/local.dsh.whale.menubar.plist
  ProgramArguments -> /Applications/大肥鱼.app/Contents/MacOS/WhaleLauncher
  RunAtLoad = true
```
