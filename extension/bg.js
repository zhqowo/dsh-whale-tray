// DSH 大肥鱼唤醒助手:每 1.5 秒问一次桌面大肥鱼是否需要唤醒 DSH 标签。
// 需要时,把主浏览器里 http://127.0.0.1:3080 的标签切到前台并聚焦窗口。
setInterval(async () => {
  try {
    const res = await fetch('http://127.0.0.1:9335/activate', { cache: 'no-store' });
    const data = await res.json();
    if (!data || !data.activate) return;
    const tabs = await chrome.tabs.query({ url: 'http://127.0.0.1:3080/*' });
    if (tabs.length > 0) {
      await chrome.tabs.update(tabs[0].id, { active: true });
      await chrome.windows.update(tabs[0].windowId, { focused: true, state: 'normal' });
    }
  } catch (e) {
    // 大肥鱼没在运行:忽略
  }
}, 1500);
