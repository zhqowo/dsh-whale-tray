# 🐳 Da Fei Yu — DeepSeek Harness Whale Tray

A system-tray **whale launcher** for [DeepSeek Harness](https://github.com/deepseek-ai) (dsh): one-click start/stop of the dsh service, wake the Web UI, restart the service, and open the usage/billing page. **Runs as an independent process** — like a Steam launcher for dsh.

## Features

| Action | Behavior |
|---|---|
| Double-click exe | Whale icon appears in the tray; auto-starts dsh if it is not running (hidden, logs to `dsh-tray.log`) |
| Left / double-click the whale | Brings up the DSH Web UI (switches to the background tab via the companion browser extension — **no duplicate tabs**) |
| Right-click → Toggle whale | Switch dsh on/off; state refreshes every 2 s |
| Right-click → Restart service | Shown only while dsh is running; stops the old service → waits for the port → restarts hidden |
| Right-click → Top-up | Opens `https://platform.deepseek.com/usage` in Edge |
| Right-click → Exit | Stops the dsh service first, then exits |

## Tech highlights

- **Independent process**: does not depend on dsh; force-killing the whale does not affect dsh and vice versa
- **Wake-up, three layers**: ① window-title match (foreground tab) ② browser extension switches the background tab (recommended) ③ fallback: open a new tab
- **Extension channel**: local port `9335` (whale signals → extension polls → `chrome.tabs.update` + `windows.update(state:'normal')` switches to the DSH tab)
- **DPI**: PerMonitorV2 awareness + system menu font (manifest)
- **Handle safety**: listener socket marked non-inheritable (prevents the dsh child process from hogging the port); 20 s self-healing rebind
- **Single instance**: mutex prevents duplicate runs

## Layout

```
WhaleTray.cs      # Main program (C#, WinForms, .NET Framework 4.x)
app.manifest      # DPI awareness manifest
whale-source.png  # Original artwork (by Yue Jiang, from Bilibili)
whale*.png/.ico   # Icons (cut-out + resized + small-size white-hair fix)
extension/        # Companion browser extension (wakes the background DSH tab)
```

## 🖼️ Artwork credit

- **Original artist: Yue Jiang (月匠, Bilibili)** — the whale-girl artwork was drawn by Bilibili artist **Yue Jiang** (source image: `whale-source.png`, from their Bilibili post).
- Bundled via the **dsh-whale-widget** plugin:
  [MeteorNOX/DeepSeek-Balance-Whale-Widget](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget) (MIT License, Copyright © 2026 MeteorNOX)
- If Yue Jiang would like the attribution adjusted, or the artwork replaced/removed, please open an issue and we will act immediately.
- This repo has: cut the artwork out, resized it to 16/32/48/256, applied a small-size white-hair enhancement, and packed it into `.ico`.

## Build (Windows)

```bat
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /target:winexe /out:DaFeiYu.exe /win32icon:whale.ico /win32manifest:app.manifest /codepage:65001 /r:System.dll /r:System.Drawing.dll /r:System.Windows.Forms.dll /r:UIAutomationClient.dll /r:UIAutomationTypes.dll WhaleTray.cs
```

## Extension setup (one-time)

1. Open `edge://extensions` → enable **Developer mode**
2. Click **Load unpacked** → select the `extension/` folder
3. Clicking the whale now silently switches to the DSH tab

## Requirements

- DeepSeek Harness (dsh)
- Edge or Chrome installed (for the wake-up feature)
