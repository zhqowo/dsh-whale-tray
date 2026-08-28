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
        string[] candidates = new string[]
        {
            @"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
            @"C:\Program Files\Microsoft\Edge\Application\msedge.exe"
        };
        foreach (string path in candidates)
        {
            if (File.Exists(path))
            {
                try { Process.Start(path, WEB_URL); return; }
                catch { }
            }
        }
        OpenWeb();   // Edge 不存在 → 退回系统默认
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