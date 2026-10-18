# 从 0 到能分发的 macOS 菜单栏 App —— 我们踩过的 24 个坑

> 这份文档不讲"什么是 app bundle"。它记的是**做「命令行程序的菜单栏外壳」这一个具体品类**时，
> 真把东西做坏、发出去装不上、授权莫名失效的那些坑，以及每个坑的准确解法。
>
> 例子全部来自本仓库的 `macos/`（大肥鱼），但每条对任何「Swift 菜单栏 + 启动/控制别的进程」的
> Mac app 都成立。想直接看代码：`macos/build.sh`、`macos/main.swift`、`macos/install.sh`。

测试环境：macOS 26.6.2 · Apple Swift 6.4（CLT）· SDK `MacOSX26.5.sdk` / `MacOSX27.0.sdk` ·
产物 `2.4 (build 6)` · `arm64 + x86_64` · `minos 13.0`。

---

## 0. 先看整条链

```
main.swift ──swiftc -target <arch>-apple-macos13.0 -O──► WhaleLauncher.<arch>
                                                        └─lipo -create─► WhaleLauncher
whale256.png ──sips -z 22/44──► 菜单栏图 whale.png / whale@2x.png
             ──icon_compose──► icon_base 1024 ──sips + iconutil──► AppIcon.icns
                                                                      │
mkdir 手搓 bundle 结构 ◄──────────────────────────────────────────────┘
        │
        └─ codesign --force --sign -      (ad-hoc)
                └─ ditto -c -k --sequesterRsrc --keepParent ──► DaFeiYu.app.zip
                        └─ gh release upload ──► releases/latest/download/DaFeiYu.app.zip
                                └─ install.sh: 下载 → ditto -x -k → xattr -dr → lsregister → 打开
```

最小可运行的 bundle：

```
大肥鱼.app/
└── Contents/
    ├── Info.plist
    ├── PkgInfo                    # 内容就 8 个字节: APPL????
    ├── MacOS/WhaleLauncher        # 可执行，名字必须等于 CFBundleExecutable
    └── Resources/
        ├── AppIcon.icns
        ├── whale.png              # 22×22  菜单栏 @1x
        └── whale@2x.png           # 44×44  菜单栏 @2x
```

---

## A. 编译

### 1. SDK 要显式钉住,别指望 `xcrun`

`xcrun --sdk macosx --show-sdk-path` 现在返回 `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk`，
而它是个**软链接，指向当时最新的 SDK**（此刻 → `MacOSX27.0.sdk`）。CLT 一升级，这个链接就跳。

我们因此吃过一次：装了 Swift 6.3.3 的编译器，`xcrun` 默认却给了 Swift **6.4 编出来的** `MacOSX27.0.sdk`，
编译器直接读不了。现在两边都是 6.4、能编通，但**换一台机器就不一定**。

所以 `build.sh` 用 glob 自己挑，还顺手排掉 27：

```zsh
SDK=$(/bin/ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX26*.sdk | head -1)
[ -z "$SDK" ] && SDK=$(/bin/ls -d .../MacOSX*.sdk | grep -v 27 | head -1)
/usr/bin/swiftc -sdk "$SDK" ...
```

顺手把 `swiftc` / `sips` / `iconutil` / `lipo` 全写成 `/usr/bin/...` 绝对路径。

### 2. 一定要 `-swift-version 5`

Swift 6 语言模式的严格并发检查会把一堆老 AppKit 写法判成错误（`@objc` 方法、全局状态、闭包捕获）。
这些代码逻辑没问题，只是不符合 Swift 6 的新规矩。加 `-swift-version 5`，别为了"用新版本"去重写能跑的东西。

### 3. ⭐ 不传 `-target`，`LSMinimumSystemVersion` 就是一句谎话

**这是最贵的一个坑，我们真的发出去了一个只有 macOS 26 能打开的包。**

`swiftc` 不指定 `-target` 时，`minos`（Mach-O 里的最低系统版本）**等于编译机的系统版本**。
`Info.plist` 里写 `LSMinimumSystemVersion 13.0` 只是给 Finder / 商店看的元数据，
**dyld 只认 `minos`**。结果：plist 说 13.0，实际 macOS 15 上一打开就 `dyld: Symbol not found` / 直接闪退。

自己验：

```sh
otool -l App.app/Contents/MacOS/App | grep -A4 LC_BUILD_VERSION   # 看 minos
```

正解 —— 每个切片都带上目标：

```zsh
swiftc -sdk "$SDK" -target arm64-apple-macos13.0  ...
swiftc -sdk "$SDK" -target x86_64-apple-macos13.0 ...
```

**发版前必查：`minos` == `LSMinimumSystemVersion`。** 两者对不上，这个包就不该发。

### 4. arm64-only 不叫"Mac 版"

只编 arm64 → 所有 Intel Mac 直接 `Bad CPU type in executable`。
通用二进制就是编两遍再合：

```zsh
lipo -create WhaleLauncher.arm64 WhaleLauncher.x86_64 -output WhaleLauncher
lipo -archs WhaleLauncher        # → x86_64 arm64
```

x86_64 那遍会刷两条警告：

```
ld: warning: ignoring file '.../libswiftCompatibilityPacks.a': fat file missing arch 'x86_64'
```

**可以忽略** —— 那是给旧系统上的 Swift **并发/async 运行时**用的兼容包。纯 AppKit + `Process` 的
代码用不到；我们核过 `otool -L`，依赖全是 `/usr/lib/swift/*` 和系统框架，没有 CLT 路径。

> ⚠️ 诚实交代：x86_64 切片**编译通过、lipo 进去了，我们手上没有 Intel 机器做真机验证**。
> Intel 用户如果启动即崩，用 `WHALE_ARCHS=arm64` 或干脆本机 `--build` 编译。

### 5. `PATH` 只留系统目录

`build.sh` 开头有：

```zsh
export PATH="$HOME/.local/node/bin:/usr/bin:/bin:/usr/sbin:/sbin"
```

因为 conda / homebrew / asdf 的 shim 会挡在前面，`swiftc`、`sips`、`python3` 可能解析到完全不同的东西
（本机就有两个 python3：conda 3.14 和系统 3.9，同一个脚本手敲和 agent 跑结果不同）。
构建脚本尤其要钉死。

---

## B. 组装 bundle

### 6. `cp -R src dst` 在 dst 已存在时会嵌套

不是覆盖，是变成 `dst/src`。每次组装前 `rm -rf "$BUNDLE"`。

### 7. Info.plist 最小键表

```xml
<key>CFBundleName</key><string>大肥鱼</string>
<key>CFBundleDisplayName</key><string>大肥鱼</string>
<key>CFBundleExecutable</key><string>WhaleLauncher</string>   <!-- = Contents/MacOS/ 里的文件名 -->
<key>CFBundleIdentifier</key><string>local.dsh.whale.menubar</string>
<key>CFBundleIconFile</key><string>AppIcon</string>           <!-- 不带 .icns -->
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleSignature</key><string>????</string>
<key>CFBundleShortVersionString</key><string>2.4</string>     <!-- 给人看的 -->
<key>CFBundleVersion</key><string>6</string>                  <!-- 必须递增 -->
<key>LSUIElement</key><true/>                                 <!-- 菜单栏 app：不进 Dock -->
<key>LSMinimumSystemVersion</key><string>13.0</string>        <!-- 必须和 minos 一致 -->
<key>NSHighResolutionCapable</key><true/>
```

`LSUIElement=true` 之后**没有 Dock 图标**，用户退出应用只能靠你的菜单项 —— 记得放「退出」。

### 8. 要控制别的 app，`NSAppleEventsUsageDescription` 别漏

菜单栏 app 想 `tell application "Microsoft Edge" ...`（把已开的 DSH 标签切到前台），
Apple Events 第一次会弹自动化授权。

**没有这个键它照样弹，但弹窗里没有一句解释**，用户不知道为什么要给、点了拒绝还得去
设置 → 隐私与安全性 → 自动化 里手动勾回来。

```xml
<key>NSAppleEventsUsageDescription</key>
<string>大肥鱼 需要控制浏览器，才能把已打开的 DSH 页面切到前台。</string>
```

### 9. `SetFile -a c` —— 注意大小写

ad-hoc 手搓的 bundle 没有"自定义图标"位，Finder 会画一个通用文件夹图标，即使 `AppIcon.icns` 就在里面。

```sh
SetFile -a c App.app     # 大写 C 是「清除」
```

### 10. icns 走 iconset，文件名必须精确

```sh
icon_16x16.png  icon_16x16@2x.png  icon_32x32.png  icon_32x32@2x.png
icon_128x128.png icon_128x128@2x.png icon_256x256.png icon_256x256@2x.png
icon_512x512.png icon_512x512@2x.png
iconutil -c icns App.iconset -o AppIcon.icns
```

少一个、名字错一个，`iconutil` 直接报错。

### 11. 菜单栏图标必须是 template image

菜单栏会跟随浅色/深色/强调色。给一张彩色图，深色模式下会糊成一团黑。

- 图：**纯黑 + alpha**，22×22 / 44×44 两档
- 代码：`image.isTemplate = true`

### 12. 换图标后 Finder 不刷新

缓存三层，逐层清：

```sh
LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
SetFile -a c "$APP"; xattr -c "$APP"; "$LSREG" -f "$APP"; touch "$APP"
killall iconservicesagent; rm -rf ~/Library/Caches/com.apple.iconservices; killall Finder
```

---

## C. 签名

### 13. ad-hoc 就够个人分发，`spctl` 报 rejected 是正常的

```sh
codesign --force --sign - App.app        # 签
codesign --verify --deep --strict App.app # valid on disk / satisfies its Designated Requirement ✅
spctl -a -vv App.app                      # → rejected  ← 正常，别当成失败
```

`spctl` 检查的是 **Gatekeeper（公证 + Developer ID）**。ad-hoc 没有 Team ID，永远 rejected，
但它是个**结构完整、能跑**的 app。真正拦住用户的是下一节的 quarantine，不是 spctl。

### 14. ⭐ ad-hoc 没有 Team ID → TCC 授权绑在 cdhash 上

有 Developer ID 时，系统认 `(bundle id, Team ID)`，换个版本重新签名，授权还在。
**ad-hoc 只能认 `(bundle id, cdhash)`**，而 cdhash 是签名的哈希 —— **代码改一个字节就变**。

后果：**每次重新编译，屏幕录制 / 辅助功能 / 完全磁盘访问全废**，用户得把它们从隐私列表删掉重加。

想让升级不打扰用户，只有一条路：买 Apple Developer 证书（99 美元/年）+ 签名 + 公证。
不买就得在文档里写清楚「升级后要去设置里重新授权」。

### 15. 绝对不要"原地重建"正在用的那个 app

重建 → cdhash 变 → 授权失效；如果脚本还顺手启动新副本，`responsible process` 也换了 → 权限**整片**失效，
而且**不报错**，只是操作静默失败。

所以 `build.sh` 有暂存模式：

```sh
WHALE_APP_OUT=/tmp/whale-staging/大肥鱼.app zsh macos/build.sh
```

这个模式下**不覆盖桌面 app、不杀运行中的进程、不启动产物**。改代码、出发布包一律走它。

---

## D. TCC / 权限（最坑的一节）

### 16. `responsible process` —— TCC 认的是"谁启动了它"

DSH 是个 terminal 程序。它调 `screencapture` / 辅助功能 API 时，TCC 不看 DSH 自己，
而是往上找到**启动它的那个 app**（responsible process），拿那个 app 的授权来判。

同一份 DSH：
- 从 `大肥鱼.app` 启动 → responsible = 大肥鱼 → 有授权 ✅
- 从终端 / Spotlight / 别处启动 → responsible = 终端 → 没授权 ❌（而且 DSH 自己看起来一切正常）

**授权是绑在 responsible process 的签名上的**。所以：

- DSH 必须由这个 app 启动（我们就是在 app 里跑 `Process` 去起 dsh）
- **这个 app 不能重新编译**（cdhash 变了，授权全废）
- 要加功能，去改**别的** app，别动这个

### 17. 两个同名同 bundle id 的 app → 授权认错对象

`~/Desktop/大肥鱼.app` 和 `/Applications/大肥鱼.app` 同 id 同时存在时，
系统可能把授权记在 A 上、实际运行 B。表现就是"明明授权了还是没权限"，且极难排查。

规矩：
- **同一时间只留一个**
- 旧版本**换 id 改名**（我们封成 `migration/old-launcher/大肥鱼-applescript.app` 存 zip，不解开）
- 授权时**从桌面拖进去**，别用 Spotlight（Spotlight 可能打开另一个同 id 的 bundle）

### 18. `pgrep -f <路径>` 会匹配到脚本自己

想检测 app 是否在跑：

```sh
pgrep -f WhaleLauncher                       # ❌ 可能匹配到正在跑这条命令的 shell
ps -Ao comm= | grep -qx "/path/to/binary"    # ✅ 只比 comm
```

### 19. 系统权限没法程序化授予

屏幕录制 / 辅助功能 / 完全磁盘访问**只能在设置里手点**（`tccutil` 只能重置，不能授予）。
安装器最多做到：把 app 装好、去隔离、替你打开那个设置面板，然后打印"请勾这三个"。

这也是"为什么不能像插件那样一条命令装完"的核心原因之一，见 `macos/README.md`。

---

## E. 打包与分发

### 20. 用 `ditto`，别用 `zip` / `tar`

```sh
ditto -c -k --sequesterRsrc --keepParent 大肥鱼.app DaFeiYu.app.zip   # 打包
ditto -x -k DaFeiYu.app.zip 目标目录                                   # 解包
```

`zip -r` 会丢掉扩展属性、符号链接、资源分支，解出来的 app 可能签名坏掉或图标丢失。
`--keepParent` 保证解出来是 `大肥鱼.app/` 而不是裸 `Contents/`。

### 21. 下载来的东西带 `com.apple.quarantine`

浏览器 / curl 下的 zip 解开后，每个文件都有隔离属性 → 双击被 Gatekeeper 拦，
报"无法打开，因为无法验证开发者"。

```sh
xattr -dr com.apple.quarantine /Applications/大肥鱼.app
xattr -d com.apple.quarantine DaFeiYu.app.zip       # 连 zip 一起清更保险
```

这一步等于替用户点了"右键 → 打开"。**必须由安装器执行**，不能指望用户自己想起来。

### 22. App Translocation：别从 Downloads 直接双击

隔离状态下的 app 如果从下载目录/zip 里直接运行，macOS 会把它**复制到一个随机的只读路径**
（`/private/var/folders/.../AppTranslocation/...`）再启动。

后果：**路径每次都变** —— 跟路径绑定的配置找不到，TCC 也可能因为路径变了而错乱。

正解：先 `mv` 到 `/Applications`（或 `~/Applications`），`xattr -dr` 去隔离，再打开。
`install.sh` 的顺序就是按这个来的。

### 23. Release 资产名要稳定，CDN 会偶发 504

安装器依赖这个固定 URL：

```
https://github.com/<user>/<repo>/releases/latest/download/DaFeiYu.app.zip
```

- **资产名别改**，改了就 404
- 第一次创建 release 后立刻请求，CDN 可能回 **504**；等几秒重试就好（我们遇到过）
- 传完校验：下载回来跟本地 `shasum -a 256` 对一遍

### 24. `curl ... | zsh` 的安装器怎么知道自己是被管道跑的

管道里 `$0` 是 `zsh`、`BASH_SOURCE` 之类都空，拿不到脚本自身路径。zsh 有个不走寻常路但可靠的写法：

```zsh
SELF="${(%):-%x}"        # 直接运行时 = 脚本路径；被管道时 = 空
```

`install.sh` 用它决定：本地有文件就读本地，没有就从 `raw.githubusercontent.com` 拉。

顺带：**从管道给脚本传参要 `-s --`**，否则 `zsh` 会把参数当自己的选项：

```sh
curl -fsSL .../install.sh | zsh -s -- --dir ~/DeepSeekHarness --port 3080
```

---

## F. 发版前检查清单

```sh
APP=/tmp/whale-staging/大肥鱼.app

# 1 架构（要有两种，或明确只发 arm64）
lipo -archs "$APP/Contents/MacOS/WhaleLauncher"

# 2 最低系统版本 —— 必须和 Info.plist 一致！
otool -l "$APP/Contents/MacOS/WhaleLauncher" | grep -A4 LC_BUILD_VERSION
/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP/Contents/Info.plist"

# 3 签名完整
codesign --verify --deep --strict --verbose=2 "$APP"

# 4 版本号
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist"

# 5 没有指向本机的绝对路径
otool -L "$APP/Contents/MacOS/WhaleLauncher" | grep -E '/Users/|/opt/|/usr/local/' && echo "❌ 有本机路径"

# 6 真跑一次（有 --print-url 这类自检钩子最好）
"$APP/Contents/MacOS/WhaleLauncher" --print-url

# 7 桌面那份没被动
codesign -dv --verbose=4 ~/Desktop/大肥鱼.app 2>&1 | grep CDHash=

# 8 打包 + 校验
ditto -c -k --sequesterRsrc --keepParent "$APP" /tmp/DaFeiYu.app.zip
shasum -a 256 /tmp/DaFeiYu.app.zip
```

---

## G. 症状对照表

| 症状 | 真实原因 |
|---|---|
| 双击闪一下就没了 / `dyld: Symbol not found` | `minos` 高于用户系统 → 坑 #3 |
| `Bad CPU type in executable` | 只编了 arm64，Intel 机器 → 坑 #4 |
| "无法打开，因为无法验证开发者" | `com.apple.quarantine` 没清 → 坑 #21 |
| 打开后图标是通用文件夹 | 没 `SetFile -a c` 或 icns 没进去 → 坑 #9/#10 |
| 菜单栏图标深色模式下糊成黑块 | 不是 template image → 坑 #11 |
| 改了图标 Finder 还是旧的 | iconservices 缓存 → 坑 #12 |
| 权限明明给了，操作还是失败 | responsible process 不对 → 坑 #16 |
| 重新编译后权限全没了 | ad-hoc 绑 cdhash → 坑 #14 |
| 授权了但另一个副本没权限 | 两个同 bundle id 的 app → 坑 #17 |
| 切前台/发 AppleScript 静默失败 | 自动化授权被拒，且没 `NSAppleEventsUsageDescription` → 坑 #8 |
| 检测进程老是判定"在跑"（假的） | `pgrep -f` 自匹配 → 坑 #18 |
| 解压出来的 app 打不开 / 图标丢 | 用 `zip` 打的包 → 坑 #20 |
| 装好之后配置读不到 | App Translocation，路径是随机的 → 坑 #22 |
| `latest/download/xxx.zip` 404 | 资产改名了 → 坑 #23 |
| `curl \| zsh --dir ...` 报 zsh 参数错 | 少了 `-s --` → 坑 #24 |

---

## 附：想省钱又想让别人装得顺

| 投入 | 得到 |
|---|---|
| 0 元（现在这样） | 一条命令装好；用户手动：去隔离已由脚本做，权限手点；**升级要重新授权** |
| 99 美元/年 Apple Developer | Gatekeeper 不再拦、可公证、**升级不用重新授权**、可以上架 |
| + 20 分钟配 CI | tag 一推自动编译 + 发布 + 算 sha256（GitHub Actions 的 macOS runner 免费额度够用） |

细节与本项目专属步骤见 [`../macos/README.md`](../macos/README.md)。
