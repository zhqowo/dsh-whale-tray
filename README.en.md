# 🐳 Da Fei Yu — DeepSeek Harness Launcher

English | [中文](README.md)

One-click start/stop for [DeepSeek Harness](https://github.com/deepseek-ai) (dsh) —
a **system tray** app on Windows, a **menu-bar** app on macOS. **Runs as an independent process**,
like a Steam launcher for dsh.

> 🦞 **Looking for the OpenClaw Lobster?** It now lives in its own repo:
> **[zhqowo/openclaw-menubar](https://github.com/zhqowo/openclaw-menubar)** — the two serve
> different audiences, so splitting them lets each be discovered and released on its own.

## Which one do I want

| Platform | Program | Shape | Source |
|---|---|---|---|
| **Windows** | `大肥鱼.exe` | system tray (bottom-right) | [`WhaleTray.cs`](WhaleTray.cs) |
| **macOS** | `大肥鱼.app` | menu bar (top-right) | [`macos/`](macos/) |

## Feature comparison

| Action | Windows | macOS |
|---|---|---|
| Toggle service | right-click → start/stop | same |
| Wake the Web UI | left / double-click the whale | left click |
| Switch to the existing tab | port `9335` + **companion extension** | **AppleScript**, no extension needed |
| Restart service | right-click → restart | same |
| Top-up page | right-click → top-up | same |
| Exit | stops dsh first, then exits | same |
| State refresh | every 2 s | every 3 s (TCP probe) |
| Shape | tray + hidden console | menu bar, silent by nature |

> **The macOS build needs no browser extension** — Chromium browsers expose their tabs to
> AppleScript, so we just select the tab. Only Windows needs the port-polling + extension combo.

⚠️ **macOS has a trap Windows doesn't: TCC permissions.**
**Before changing code, moving machines, or rebuilding, read the TCC section of
[`macos/README.md`](macos/README.md).** Its three rules were paid for in debugging time —
violating any of them silently kills every permission the app has.

---

# 🐳 Da Fei Yu

## Windows build

| Action | Behavior |
|---|---|
| Double-click exe | Whale icon appears in the tray; auto-starts dsh if not running (hidden, logs to `dsh-tray.log`) |
| Left / double-click the whale | Brings up the DSH Web UI (switches to the background tab via the companion extension — **no duplicate tabs**) |
| Right-click → Toggle | Switch dsh on/off; state refreshes every 2 s |
| Right-click → Restart | Shown only while dsh runs; stops the old service → waits for the port → restarts hidden |
| Right-click → Top-up | Opens `https://platform.deepseek.com/usage` in Edge |
| Right-click → Exit | Stops the dsh service first, then exits |

### Tech highlights (Windows)

- **Independent process**: does not depend on dsh; force-killing the whale does not affect dsh and vice versa
- **Wake-up, three layers**: ① window-title match (foreground tab) ② extension switches the background tab (recommended) ③ fallback: open a new tab
- **Extension channel**: local port `9335` (whale signals → extension polls → `chrome.tabs.update` + `windows.update(state:'normal')`)
- **DPI**: PerMonitorV2 awareness + system menu font (`app.manifest`)
- **Handle safety**: listener socket marked non-inheritable; 20 s self-healing rebind when the port is taken
- **Single instance**: mutex prevents duplicate runs

### Build (Windows)

```bat
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /target:winexe /out:DaFeiYu.exe /win32icon:whale.ico /win32manifest:app.manifest /codepage:65001 /r:System.dll /r:System.Drawing.dll /r:System.Windows.Forms.dll /r:System.Web.Extensions.dll /r:UIAutomationClient.dll /r:UIAutomationTypes.dll WhaleTray.cs
```

### Extension setup (one-time)

1. Open `edge://extensions` → enable **Developer mode**
2. Click **Load unpacked** → select the `extension/` folder
3. Clicking the whale now silently switches to the DSH tab

## macOS build

A Swift + Cocoa `NSStatusItem` app. A whale in the menu bar: **left click switches to the DSH tab,
right click opens the menu** (status · toggle · restart · open web · top-up · quit); full colour while
running, dimmed while stopped.

```sh
cd macos && zsh build.sh     # builds and installs ~/Desktop/大肥鱼.app
```

Details — icon composition, how left/right click separation works, AppleScript gotchas, and the
**must-read TCC permission section** — live in [`macos/README.md`](macos/README.md).

---

## ⚙️ Configuration (optional, both platforms)

**It works with no configuration at all** — the defaults target a standard DeepSeek + dsh setup.

<details>
<summary><b>The "Top up" item points at DeepSeek — how do I change it?</b></summary>

The menu's **Top up** entry opens `https://platform.deepseek.com/usage` by default.
But this launcher only starts/stops the dsh service — it has nothing to do with which model
provider you use, and you are free to run something other than DeepSeek.

Drop a JSON file and you can repoint it **without recompiling**:

<table>
<tr><th>Platform</th><th>Path</th></tr>
<tr><td>macOS</td><td><code>~/.config/dsh-whale-tray/config.json</code></td></tr>
<tr><td>Windows</td><td><code>%APPDATA%\dsh-whale-tray\config.json</code></td></tr>
</table>

> The `DSH_WHALE_TRAY_CONFIG` environment variable overrides the path on either platform.

```jsonc
{
  // page the billing entry opens
  "billingUrl":   "https://your-provider.example/billing",
  // text shown for that menu item (default: 充值)
  "billingLabel": "Billing",

  // Windows only: where your dsh is installed.
  // Left out, it probes D:\DeepSeekHarness, then %USERPROFILE%\DeepSeekHarness
  "dshHome":      "C:\\DeepSeekHarness"
}
```

| key | default | what it does |
|---|---|---|
| `billingUrl` | `https://platform.deepseek.com/usage` | page the billing entry opens |
| `billingLabel` | `充值` | label of that menu item |
| `dshHome` | auto-detected | **Windows only**: dsh install root |

- **Every key is optional** — set only the ones you care about
- Missing file / malformed JSON / wrong type → **silently falls back to the defaults**; the tray
  or menu bar must never fail to come up over an optional config
- The CLI (`macos/dsh-ctl.sh billing`) reads the same file
- JSON comments are not supported — the block above is marked `jsonc` only to allow annotations
</details>

---

# 🦞 OpenClaw Lobster → moved to its own repo

The OpenClaw gateway menu-bar toggle **used to** live here. It has moved to:

### 👉 **[zhqowo/openclaw-menubar](https://github.com/zhqowo/openclaw-menubar)**

Source, build scripts, icon assets and releases all live there now.
The old `openclaw/` directory was removed from this repo.

---

## Install as a DSH plugin

This repo declares a `dsh.bundle` manifest, so it can be installed as a plugin
(lets the agent discover and manage the launcher):

```sh
dsh plugin --profile web add github:zhqowo/dsh-whale-tray
```

> What gets installed is only the **manifest** — the app that does the work is the tray/menu-bar
> binary built from `WhaleTray.cs` / `macos/`. Desktop apps cannot be distributed over npm;
> this entry point exists so DSH can discover it.

## Downloads

`dist/` holds the packaged macOS apps (unzip and run):

| File | What |
|---|---|
| `dist/大肥鱼.app.zip` | macOS menu-bar Da Fei Yu |

> 🦞 The OpenClaw Lobster download lives in the new repo:
> [openclaw-menubar/releases](https://github.com/zhqowo/openclaw-menubar/releases/latest)

> Because they are ad-hoc signed, Gatekeeper blocks the first launch: right-click → **Open**, or
> `xattr -d com.apple.quarantine 大肥鱼.app`.
> ⚠️ **Do not rebuild `大肥鱼.app` yourself** — a rebuild changes its cdhash and invalidates every
> TCC permission it holds.

## Layout

```
WhaleTray.cs      # Windows main program (C#, WinForms, .NET Framework 4.x)
app.manifest      # Windows DPI awareness manifest
extension/        # Windows companion extension (wakes the background DSH tab)
whale*.*          # Windows icons (cut-out + resized + small-size white-hair fix)
macos/            # macOS Da Fei Yu (Swift) + dsh-ctl.sh
tools/            # Helper tools (check-perms.sh health check / uictl UI automation)
dist/             # Packaged macOS .app bundles
package.json      # dsh plugin manifest (declares dsh.bundle for `dsh plugin add`)
cordis.patch.yml  # the patch file that manifest points at
```

> 🦞 The OpenClaw Lobster moved to [zhqowo/openclaw-menubar](https://github.com/zhqowo/openclaw-menubar).

## 🖼️ Artwork credit

**I did not draw the whale — here is where it comes from.** Every icon on both platforms is
derived from that one original.

- **Original artist: Yue Jiang (月匠, Bilibili)** — the whale-girl artwork was drawn by the Bilibili
  artist **Yue Jiang** (source image: [`whale-source.png`](whale-source.png), from their Bilibili post)
- **Obtained via** the **dsh-whale-widget** plugin —
  [MeteorNOX/DeepSeek-Balance-Whale-Widget](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget)
  (MIT License, Copyright © 2026 MeteorNOX)
- If Yue Jiang would like the credit adjusted, or the artwork replaced or removed, please open an
  issue and **it will be handled immediately**

No artistic changes were made — only mechanical ones:

| File | Platform | How it was produced |
|---|---|---|
| `whale.ico` | Windows | cropped → resized to 16/32/48/256 → packed as ico |
| `whale16/32/48/256.png` | Windows | the same, as individual size files |
| `macos/whale256.png` | macOS | the original downscaled to 256 (the build's starting asset) |
| menu-bar `whale.png` / `whale@2x.png` | macOS | the above via `sips -z` to **22px / 44px** |
| the app icon `AppIcon.icns` | macOS | the above laid over a gradient card (`icon_compose.swift`), converted to icns |

> **Small sizes get a white-hair brightening pass** — shrunk to 16px the original's lines smear into
> a dark blob; brightening them is what makes it legible.
>
> The macOS 22px icon has its own trap: `NSImage(contentsOfFile:)` does **not** auto-load the `@2x`
> sibling, so a single rep looks fuzzy on Retina. The build script ships both.
>
> Full third-party asset notice: [NOTICE](NOTICE).


## Requirements

- DeepSeek Harness (dsh)
- Windows: Edge or Chrome installed (for the wake-up feature)
- macOS: Edge or Chrome installed (for tab switching); see `macos/README.md` for the dsh side

## License

[MIT](LICENSE) © 2026 zhqowo — use it, change it, ship it commercially; just keep the copyright notice.

⚠️ Artwork is the exception: **the whale artwork is © Yue Jiang (月匠, Bilibili)** — see the
"Artwork credit" section above for the attribution chain. Keep that credit if you redistribute.
