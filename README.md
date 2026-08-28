# 🐳 大肥鱼(DeepSeek Harness Whale Tray)

DSH(DeepSeek Harness)右下角**托盘小鲸鱼**:一键开关 dsh 服务、唤起 Web、重启服务、一键充值。**独立于 dsh 进程**,类似 Steam 的启动器。

## 功能

| 操作 | 行为 |
|---|---|
| 双击 exe | 托盘出现鲸鱼;dsh 没开自动启动(隐藏运行,日志写 `dsh-tray.log`) |
| 左键 / 双击鲸鱼 | 唤起 DSH Web(通过配套浏览器扩展切换后台标签,**不新开页**) |
| 右键 → 开启/关闭大肥鱼 | 动态切换,dsh 状态每 2 秒自动刷新 |
| 右键 → 重启服务 | 仅 dsh 运行时显示;停旧服务 → 等端口释放 → 隐藏重启 |
| 右键 → 充值 | 在 Edge 中打开 `https://platform.deepseek.com/usage` |
| 右键 → 退出 | 先关 dsh 服务,再退出程序 |

## 技术要点

- **独立进程**:不依赖 dsh;强杀鲸鱼不影响 dsh,反之亦然
- **唤起 Web 三层方案**:① 窗口标题匹配(前台标签)② 浏览器扩展唤醒后台标签(推荐)③ 兜底新开
- **扩展通信**:本地端口 `9335`(鲸鱼发信号 → 扩展轮询 → `chrome.tabs.update` + `windows.update(state:'normal')` 切到 DSH 标签)
- **DPI**:PerMonitorV2 感知 + 系统菜单字体(manifest)
- **句柄安全**:监听 socket 标记不可继承(防止 dsh 子进程占用端口),端口被占时 20s 自愈重试
- **单实例**:互斥锁防止重复运行

## 目录

```
WhaleTray.cs      # 主程序(C#, WinForms, .NET Framework 4.x)
app.manifest      # DPI 感知清单
whale*.png/.ico   # 图标(基于 dsh-whale-widget 素材制作,白头发修复版)
extension/        # 配套浏览器扩展(唤醒后台 DSH 标签)
```

## 🖼️ 图标出处

- 图标素材来自 **dsh-whale-widget(DeepSeek 余额小鲸鱼挂件)插件**,仓库:
  [MeteorNOX/DeepSeek-Balance-Whale-Widget](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget)(MIT License,Copyright © 2026 MeteorNOX)
- 插件内**未标注鲸鱼素材的原始画师/作者**(仅以 "DSniang" 命名,疑似 DeepSeek 娘化同人图)。
  若素材作者看到并希望署名或删除,请提 issue,我们立即处理。
- 本仓库对原图做了:裁剪(cut-out)、缩放到 16/32/48/256、小尺寸白色提亮修复,并打包为 `.ico`。

## 构建(Windows)

```bat
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /target:winexe /out:大肥鱼.exe /win32icon:whale.ico /win32manifest:app.manifest /codepage:65001 /r:System.dll /r:System.Drawing.dll /r:System.Windows.Forms.dll /r:UIAutomationClient.dll /r:UIAutomationTypes.dll WhaleTray.cs
```

## 扩展安装(一次性)

1. `edge://extensions` → 打开「开发人员模式」
2. 「加载解压缩的扩展」→ 选择 `extension/` 目录
3. 以后点鲸鱼即可静默切换 DSH 标签

## 依赖

- DeepSeek Harness(dsh)
- 系统已装 Edge / Chrome(唤起用)
