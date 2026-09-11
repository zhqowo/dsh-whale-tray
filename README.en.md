# 🐳 Da Fei Yu — DeepSeek Harness Launcher

English | [中文](README.md)

One-click start/stop for [DeepSeek Harness](https://github.com/deepseek-ai) (dsh) —
a **system tray** app on Windows, a **menu-bar** app on macOS. **Runs as an independent process**,
like a Steam launcher for dsh.

This repo also ships **🦞 OpenClaw Lobster** for macOS — the same skeleton, pointed at the
OpenClaw gateway instead.

## Which one do I want

| Platform | Program | Shape | Source |
|---|---|---|---|
| **Windows** | `大肥鱼.exe` | system tray (bottom-right) | [`WhaleTray.cs`](WhaleTray.cs) |
| **macOS** | `大肥鱼.app` | menu bar (top-right) | [`macos/`](macos/) |
| **macOS** | `OpenClaw.app` 🦞 | menu bar (top-right) | [`openclaw/`](openclaw/) |

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
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /target:winexe /out:DaFeiYu.exe /win32icon:whale.ico /win32manifest:app.manifest /codepage:65001 /r:System.dll /r:System.Drawing.dll /r:System.Windows.Forms.dll /r:UIAutomationClient.dll /r:UIAutomationTypes.dll WhaleTray.cs
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

# 🦞 OpenClaw Lobster (macOS)

One-click toggle for the OpenClaw gateway. Simpler than Da Fei Yu:
**left click opens the Control UI, right click offers only "Start gateway / Quit"**.

- The gateway runs under **launchd**, so starting it is silent and windowless
- Left click reads the token from the config and builds the URL — **the Control UI opens
  pre-authenticated**
- **Quitting also stops the gateway**
- The icon is OpenClaw's official vector mascot, rasterised from the SVG shipped in its own npm package

```sh
cd openclaw && zsh build.sh          # builds and installs ~/Desktop/OpenClaw.app
cd openclaw && zsh make_assets.sh    # refresh icon assets after upgrading OpenClaw
```

Details in [`openclaw/README.md`](openclaw/README.md).

---

## Downloads

`dist/` holds the packaged macOS apps (unzip and run):

| File | What |
|---|---|
| `dist/大肥鱼.app.zip` | macOS menu-bar Da Fei Yu |
| `dist/OpenClaw.app.zip` | macOS menu-bar OpenClaw Lobster |

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
openclaw/         # macOS OpenClaw Lobster (Swift) + openclaw-ctl.sh
tools/            # Helper tools (check-perms.sh health check / uictl UI automation)
dist/             # Packaged macOS .app bundles
```

## 🖼️ Artwork credit

- **Original artist: Yue Jiang (月匠, Bilibili)** — the whale-girl artwork was drawn by Bilibili artist **Yue Jiang** (source image: `whale-source.png`, from their Bilibili post).
- Bundled via the **dsh-whale-widget** plugin:
  [MeteorNOX/DeepSeek-Balance-Whale-Widget](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget) (MIT License, Copyright © 2026 MeteorNOX)
- If Yue Jiang would like the attribution adjusted, or the artwork replaced/removed, please open an issue and we will act immediately.
- This repo has: cut the artwork out, resized it to 16/32/48/256, applied a small-size white-hair enhancement, and packed it into `.ico`.
- The **OpenClaw lobster** comes from the SVG inside OpenClaw's own npm package (`dist/control-ui/favicon.svg`); the vector original is kept in `openclaw/assets/`.

## Requirements

- DeepSeek Harness (dsh)
- Windows: Edge or Chrome installed (for the wake-up feature)
- macOS: Edge or Chrome installed (for tab switching); see `macos/README.md` for the dsh side
