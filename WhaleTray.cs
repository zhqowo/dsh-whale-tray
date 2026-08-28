using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Drawing;
using System.IO;
using System.Threading;
using System.Windows.Automation;
using System.Windows.Forms;

public class WhaleTray : Form
{
    private NotifyIcon tray;
    private ContextMenuStrip menu;
    private ToolStripMenuItem toggleItem;
    private ToolStripMenuItem restartItem;
    private ToolStripMenuItem rechargeItem;
    private System.Windows.Forms.Timer clickTimer;
    private System.Windows.Forms.Timer refreshTimer;
    private Icon whaleIcon;
    private Bitmap whaleBmp;
    private bool dblClicked;
    private volatile bool activatePending = false;
    private volatile bool pollBound = false;
    private System.Net.Sockets.TcpListener pollListener;
    private static Mutex singleInstance;

    private const string WHALE_B64 = "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";
    private const string BASE_DIR = @"D:\DeepSeekHarness\projects";
    private const string DSH_CMD = @"D:\DeepSeekHarness\node_modules\.bin\dsh.CMD";
    private const string WEB_URL = "http://127.0.0.1:3080";

    [STAThread]
    public static void Main()
    {
        bool createdNew;
        singleInstance = new Mutex(true, "DSHWhaleTray_SingleInstance", out createdNew);
        if (!createdNew) return;
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new WhaleTray());
    }

    public WhaleTray()
    {
        try
        {
            byte[] bytes = Convert.FromBase64String(WHALE_B64);
            using (MemoryStream ms = new MemoryStream(bytes))
            {
                whaleBmp = new Bitmap(ms);
                whaleIcon = Icon.FromHandle(whaleBmp.GetHicon());
            }
        }
        catch
        {
            whaleBmp = null;
            whaleIcon = SystemIcons.Application;
        }

        tray = new NotifyIcon();
        tray.Icon = whaleIcon;
        tray.Text = "DSH 小鲸鱼";
        tray.Visible = true;

        menu = new ContextMenuStrip();
        menu.Font = SystemFonts.MenuFont;
        toggleItem = new ToolStripMenuItem("关闭大肥鱼");
        toggleItem.Click += delegate { ToggleDsh(); };
        menu.Items.Add(toggleItem);
        restartItem = new ToolStripMenuItem("重启服务");
        restartItem.Click += delegate { RestartDsh(); };
        menu.Items.Add(restartItem);
        rechargeItem = new ToolStripMenuItem("充值");
        rechargeItem.Click += delegate { OpenUrlInBrowser("https://platform.deepseek.com/usage"); };
        menu.Items.Add(rechargeItem);
        menu.Items.Add(new ToolStripSeparator());
        ToolStripMenuItem exitItem = new ToolStripMenuItem("退出");
        exitItem.Click += delegate { ExitApp(); };
        menu.Items.Add(exitItem);
        tray.ContextMenuStrip = menu;

        clickTimer = new System.Windows.Forms.Timer();
        clickTimer.Interval = 350;
        clickTimer.Tick += delegate { clickTimer.Stop(); if (!dblClicked) EnsureWeb(); };

        tray.MouseClick += delegate(object s, MouseEventArgs e)
        {
            if (e.Button == MouseButtons.Left) { dblClicked = false; clickTimer.Start(); }
        };
        tray.MouseDoubleClick += delegate(object s, MouseEventArgs e)
        {
            dblClicked = true; clickTimer.Stop(); EnsureWeb();
        };

        refreshTimer = new System.Windows.Forms.Timer();
        refreshTimer.Interval = 2000;
        refreshTimer.Tick += delegate { RefreshState(); };
        refreshTimer.Start();

        StartPollServer();
        ThreadPool.QueueUserWorkItem(delegate { EnsureStarted(); });
    }

    private void RefreshState()
    {
        bool running = IsDshRunning();
        toggleItem.Text = running ? "关闭大肥鱼" : "开启大肥鱼";
        restartItem.Visible = running;
        tray.Text = running ? "DSH 运行中 · 左键打开 Web" : "DSH 未运行 · 双击启动";
    }

    private bool IsDshRunning()
    {
        return GetDshPid() != 0;
    }

    private int GetDshPid()
    {
        try
        {
            ProcessStartInfo psi = new ProcessStartInfo("netstat", "-ano -p tcp");
            psi.UseShellExecute = false;
            psi.RedirectStandardOutput = true;
            psi.CreateNoWindow = true;
            using (Process p = Process.Start(psi))
            {
                string outp = p.StandardOutput.ReadToEnd();
                p.WaitForExit(5000);
                foreach (string line in outp.Split('\n'))
                {
                    if (line.Contains(":3080") && line.Contains("LISTENING"))
                    {
                        string[] parts = line.Split(new char[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
                        if (parts.Length >= 5)
                        {
                            int pid;
                            if (int.TryParse(parts[parts.Length - 1], out pid)) return pid;
                        }
                    }
                }
            }
        }
        catch { }
        return 0;
    }

    private void StartDsh()
    {
        if (IsDshRunning()) return;
        try
        {
            string log = Path.Combine(BASE_DIR, "dsh-tray.log");
            string args = "/c call \"" + DSH_CMD + "\" web >> \"" + log + "\" 2>&1";
            ProcessStartInfo psi = new ProcessStartInfo("cmd.exe", args);
            psi.WorkingDirectory = BASE_DIR;
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            psi.WindowStyle = ProcessWindowStyle.Hidden;
            Process.Start(psi);
        }
        catch (Exception ex)
        {
            tray.ShowBalloonTip(4000, "小鲸鱼", "启动 dsh 失败: " + ex.Message, ToolTipIcon.Error);
        }
    }

    private void StopDsh()
    {
        int pid = GetDshPid();
        if (pid == 0) return;
        try
        {
            ProcessStartInfo psi = new ProcessStartInfo("taskkill", "/PID " + pid + " /F");
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            using (Process p = Process.Start(psi)) { p.WaitForExit(5000); }
        }
        catch { }
    }

    private void OpenWeb()
    {
        try { Process.Start(WEB_URL); }
        catch { }
    }

    private static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
    private static readonly IntPtr HWND_NOTOPMOST = new IntPtr(-2);
    private const uint SWP_NOMOVE = 0x0002;
    private const uint SWP_NOSIZE = 0x0001;
    private const uint SWP_SHOWWINDOW = 0x0040;

    private bool IsWantedBrowser(IntPtr h)
    {
        try
        {
            uint pid;
            GetWindowThreadProcessId(h, out pid);
            if (pid == 0) return false;
            using (Process p = Process.GetProcessById((int)pid))
            {
                string n = p.ProcessName.ToLowerInvariant();
                return n == "msedge" || n == "chrome" || n == "firefox" || n == "brave" || n == "opera";
            }
        }
        catch { return false; }
    }

    private void OpenWebInEdge()
    {
        OpenUrlInBrowser(WEB_URL);
    }

    private void OpenUrlInBrowser(string url)
    {
        string[] candidates = new string[]
        {
            @"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
            @"C:\Program Files\Microsoft\Edge\Application\msedge.exe"
        };
        foreach (string path in candidates)
        {
            if (File.Exists(path))
            {
                try { Process.Start(path, url); return; }
                catch { }
            }
        }
        try { Process.Start(url); } catch { }   // Edge 不存在 → 退回系统默认
    }

    private void EnsureStarted()
    {
        if (!IsDshRunning())
        {
            StartDsh();
            tray.ShowBalloonTip(2500, "小鲸鱼", "大肥鱼启动中(隐藏运行)...", ToolTipIcon.Info);
        }
    }

    private void EnsureWeb()
    {
        ThreadPool.QueueUserWorkItem(delegate
        {
            if (!IsDshRunning()) StartDsh();
            for (int i = 0; i < 40; i++)
            {
                if (IsDshRunning()) break;
                Thread.Sleep(1000);
            }
            BringUpWeb();
        });
    }

    private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    private static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")]
    private static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll")]
    private static extern int GetWindowTextLength(IntPtr hWnd);
    [DllImport("user32.dll")]
    private static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")]
    private static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("user32.dll")]
    private static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    [DllImport("user32.dll")]
    private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    private static extern bool BringWindowToTop(IntPtr hWnd);
    [DllImport("user32.dll")]
    private static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetHandleInformation(IntPtr hObject, uint dwMask, uint dwFlags);
    private const uint HANDLE_FLAG_INHERIT = 0x1;

    private void BringUpWeb()
    {
        IntPtr found = FindDshWindowByTitle();
        if (found == IntPtr.Zero) found = FindDshTabWindow();   // UIA(部分机器可用)
        if (found != IntPtr.Zero) { ActivateWindow(found); return; }

        // DSH 标签在后台:通过"大肥鱼唤醒助手"扩展,让主浏览器把标签切到前台
        activatePending = true;
        ThreadPool.QueueUserWorkItem(delegate
        {
            for (int i = 0; i < 16; i++)   // 最多等 ~8 秒给扩展响应
            {
                Thread.Sleep(500);
                IntPtr w = FindDshWindowByTitle();
                if (w != IntPtr.Zero)
                {
                    IntPtr target = w;
                    try { BeginInvoke(new Action(delegate { ActivateWindow(target); })); } catch { }
                    return;
                }
            }
            // 扩展没装/没生效 → 退回新开
            try { BeginInvoke(new Action(OpenWebInEdge)); } catch { }
        });
    }

    private void StartPollServer()
    {
        Thread t = new Thread(delegate() { EnsurePollServerRunning(); });
        t.IsBackground = true;
        t.Start();
    }

    private void EnsurePollServerRunning()
    {
        while (true)
        {
            if (!pollBound)
            {
                try
                {
                    pollListener = new System.Net.Sockets.TcpListener(System.Net.IPAddress.Loopback, 9335);
                    pollListener.Start();
                    // 禁止句柄继承:否则 dsh 子进程会继承本监听 socket,鲸鱼退出后端口被占死
                    try { SetHandleInformation(pollListener.Server.Handle, HANDLE_FLAG_INHERIT, 0); } catch { }
                    pollBound = true;
                    Thread loop = new Thread(delegate() { PollServerLoop(); });
                    loop.IsBackground = true;
                    loop.Start();
                }
                catch { pollListener = null; }
            }
            Thread.Sleep(20000);   // 端口被占用时每 20 秒重试,自愈
        }
    }

    private void PollServerLoop()
    {
        while (true)
        {
            try
            {
                using (System.Net.Sockets.TcpClient client = pollListener.AcceptTcpClient())
                {
                    try { SetHandleInformation(client.Client.Handle, HANDLE_FLAG_INHERIT, 0); } catch { }
                    client.ReceiveTimeout = 2000;
                    client.SendTimeout = 2000;
                    using (var stream = client.GetStream())
                    {
                        byte[] buf = new byte[2048];
                        int n = stream.Read(buf, 0, buf.Length);
                        string req = System.Text.Encoding.ASCII.GetString(buf, 0, n);
                        string body;
                        if (req.StartsWith("GET /activate"))
                        {
                            bool flag = activatePending;
                            activatePending = false;
                            body = flag ? "{\"activate\":true}" : "{\"activate\":false}";
                        }
                        else body = "{\"activate\":false}";
                        string resp = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: " + body.Length + "\r\nConnection: close\r\n\r\n" + body;
                        byte[] outBytes = System.Text.Encoding.ASCII.GetBytes(resp);
                        stream.Write(outBytes, 0, outBytes.Length);
                    }
                }
            }
            catch { Thread.Sleep(200); }
        }
    }



    private string ProcessNameOf(IntPtr h)
    {
        try
        {
            uint pid;
            GetWindowThreadProcessId(h, out pid);
            using (Process p = Process.GetProcessById((int)pid)) return p.ProcessName.ToLowerInvariant();
        }
        catch { return ""; }
    }

    private IntPtr FindDshWindowByTitle()
    {
        IntPtr found = IntPtr.Zero;
        EnumWindows(delegate(IntPtr h, IntPtr l)
        {
            if (!IsWindowVisible(h) || !IsWantedBrowser(h)) return true;
            int len = GetWindowTextLength(h);
            if (len <= 0) return true;
            StringBuilder sb = new StringBuilder(len + 1);
            GetWindowText(h, sb, sb.Capacity);
            if (sb.ToString().Contains("DeepSeek Harness")) { found = h; return false; }
            return true;
        }, IntPtr.Zero);
        return found;
    }

    private IntPtr FindDshTabWindow()
    {
        try
        {
            AutomationElement root = AutomationElement.RootElement;
            AutomationElementCollection wins = root.FindAll(TreeScope.Children, Condition.TrueCondition);
            foreach (AutomationElement win in wins)
            {
                if (win == null) continue;
                int pid = 0;
                try { pid = win.Current.ProcessId; } catch { continue; }
                if (pid == 0) continue;
                string proc = null;
                try { using (Process p = Process.GetProcessById(pid)) { proc = p.ProcessName.ToLowerInvariant(); } } catch { continue; }
                if (proc != "msedge" && proc != "chrome" && proc != "firefox" && proc != "brave" && proc != "opera") continue;
                AutomationElementCollection tabs;
                try
                {
                    tabs = win.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem));
                }
                catch { continue; }
                foreach (AutomationElement tab in tabs)
                {
                    string name;
                    try { name = tab.Current.Name; } catch { continue; }
                    if (!string.IsNullOrEmpty(name) && name.Contains("DeepSeek Harness"))
                    {
                        try
                        {
                            SelectionItemPattern sel = (SelectionItemPattern)tab.GetCurrentPattern(SelectionItemPattern.Pattern);
                            if (sel != null) sel.Select();
                        }
                        catch { }
                        int hwnd = 0;
                        try { hwnd = (int)win.Current.NativeWindowHandle; } catch { }
                        return new IntPtr(hwnd);
                    }
                }
            }
        }
        catch { }
        return IntPtr.Zero;
    }

    private void ActivateWindow(IntPtr hwnd)
    {
        if (hwnd == IntPtr.Zero) return;
        // 只有最小化才还原;最大化和普通窗口绝不改变尺寸/状态
        if (IsIconic(hwnd))
        {
            ShowWindow(hwnd, 9);   // SW_RESTORE
            // 等待还原动画完成,否则 SetForegroundWindow 会被忽略
            for (int i = 0; i < 20; i++)
            {
                if (!IsIconic(hwnd)) break;
                Thread.Sleep(50);
            }
        }
        // topmost 闪现强制置前(随后立即取消),再配合 Alt 技巧解锁前台
        SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
        SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
        keybd_event(0x12, 0, 0, UIntPtr.Zero);      // Alt 键技巧绕过前台锁
        keybd_event(0x12, 0, 2, UIntPtr.Zero);
        SetForegroundWindow(hwnd);
        BringWindowToTop(hwnd);
    }

    private void RestartDsh()
    {
        ThreadPool.QueueUserWorkItem(delegate
        {
            StopDsh();
            for (int i = 0; i < 20; i++)
            {
                if (!IsDshRunning()) break;
                Thread.Sleep(500);
            }
            StartDsh();
            try { BeginInvoke(new Action(delegate
            {
                tray.ShowBalloonTip(2500, "大肥鱼", "重启完成(隐藏运行)", ToolTipIcon.Info);
                RefreshState();
            })); } catch { }
        });
    }

    private void ToggleDsh()
    {
        if (IsDshRunning())
        {
            StopDsh();
            tray.ShowBalloonTip(2000, "小鲸鱼", "大肥鱼已关闭", ToolTipIcon.Info);
        }
        else
        {
            StartDsh();
            tray.ShowBalloonTip(2000, "小鲸鱼", "大肥鱼启动中...", ToolTipIcon.Info);
        }
        RefreshState();
    }

    private void ExitApp()
    {
        StopDsh();
        tray.Visible = false;
        Application.Exit();
    }

    protected override void SetVisibleCore(bool value)
    {
        base.SetVisibleCore(false);
    }
}