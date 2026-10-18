// 大肥鱼 — macOS menu-bar launcher for DeepSeek Harness.
// The macOS counterpart of the Windows tray app: a whale icon living in the
// menu bar, showing service state and offering start/stop/restart/open/billing.
import Cocoa

let HOME = NSHomeDirectory()

// MARK: - optional user config

/// Optional config file, so the launcher can drive a DSH that lives somewhere other
/// than `~/DeepSeekHarness`, on a port other than 3080, with a browser other than
/// Edge — and so people whose dsh does not run DeepSeek models can point the billing
/// entry somewhere else — all **without recompiling**.
///
/// Looked up in order — the first existing file wins, and every key is optional:
///
///   1. `$DSH_WHALE_TRAY_CONFIG`                    explicit path to a JSON file
///   2. `~/.config/dsh-whale-tray/config.json`
///
/// Recognised keys:
///
///   | key            | default                                 |
///   |----------------|-----------------------------------------|
///   | `dshDir`       | `~/DeepSeekHarness`                     |
///   | `ctlPath`      | `<dshDir>/bin/dsh-ctl.sh`               |
///   | `port`         | `3080`                                  |
///   | `browser`      | `Microsoft Edge`                        |
///   | `billingUrl`   | `https://platform.deepseek.com/usage`   |
///   | `billingLabel` | `充值`                                   |
///
/// A malformed or unreadable file is ignored silently on purpose: the menu bar must
/// never fail to come up because of a typo in an optional config.
struct WhaleConfig {
    var billingUrl = "https://platform.deepseek.com/usage"
    var billingLabel = "充值"
    var dshDir = "\(HOME)/DeepSeekHarness"
    var ctlPathOverride: String? = nil
    var portNumber = 3080
    var browser = "Microsoft Edge"

    /// The service-control script the launcher shells out to. *Everything* that
    /// touches the DSH process goes through it, so a machine with a different layout
    /// only has to point `dshDir` (or `ctlPath`) somewhere else.
    var ctlPath: String {
        if let override = ctlPathOverride, !override.isEmpty {
            return (override as NSString).expandingTildeInPath
        }
        return "\(dshDir)/bin/dsh-ctl.sh"
    }

    /// Clamped, so a typo in the config can never produce a nonsense `sin_port`.
    var port: UInt16 { UInt16(max(1, min(65535, portNumber))) }

    /// Recomputed on each lookup rather than cached in a `static let`: the lookup is
    /// trivially cheap, and caching it silently pins the first environment it ever saw.
    static var searchPaths: [String] {
        var paths: [String] = []
        if let explicit = ProcessInfo.processInfo.environment["DSH_WHALE_TRAY_CONFIG"],
           !explicit.isEmpty {
            paths.append((explicit as NSString).expandingTildeInPath)
        }
        paths.append("\(HOME)/.config/dsh-whale-tray/config.json")
        return paths
    }

    static func load() -> WhaleConfig {
        var cfg = WhaleConfig()
        for path in searchPaths {
            guard let data = FileManager.default.contents(atPath: path),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            if let url = obj["billingUrl"] as? String, !url.isEmpty { cfg.billingUrl = url }
            if let label = obj["billingLabel"] as? String, !label.isEmpty { cfg.billingLabel = label }
            if let dir = obj["dshDir"] as? String, !dir.isEmpty {
                cfg.dshDir = (dir as NSString).expandingTildeInPath
            }
            if let ctl = obj["ctlPath"] as? String, !ctl.isEmpty { cfg.ctlPathOverride = ctl }
            if let port = obj["port"] as? Int { cfg.portNumber = port }
            if let browser = obj["browser"] as? String, !browser.isEmpty { cfg.browser = browser }
            break
        }
        return cfg
    }
}

let CONFIG = WhaleConfig.load()


// MARK: - helpers

/// Cheap liveness probe: try a TCP connect to the dsh web port.
func dshIsRunning() -> Bool {
    let sock = socket(AF_INET, SOCK_STREAM, 0)
    if sock < 0 { return false }
    defer { close(sock) }

    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = CONFIG.port.bigEndian
    addr.sin_addr.s_addr = inet_addr("127.0.0.1")
    addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)

    let rc = withUnsafePointer(to: &addr) { ptr in
        ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
            connect(sock, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    return rc == 0
}

/// POSIX single-quote escaping. Without this a `dshDir` containing a space
/// (`~/Code/Deep Seek Harness`) would be split by zsh into two arguments.
func shellQuote(_ s: String) -> String {
    "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

/// Run a shell command with a PATH that can find node/pnpm.
@discardableResult
func shell(_ args: [String]) -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/zsh")
    p.arguments = ["-lc", args.map(shellQuote).joined(separator: " ")]
    var env = ProcessInfo.processInfo.environment
    env["PATH"] = "\(HOME)/.local/node/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    p.environment = env
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = pipe
    do { try p.run() } catch { return "error: \(error.localizedDescription)" }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

func ctl(_ arg: String) -> String { shell([CONFIG.ctlPath, arg]) }

/// True when the service-control script the launcher depends on is actually there.
/// Everything the menu bar does (start/stop/restart/url) funnels through it, so a
/// missing script would otherwise surface as a silently dead menu.
func ctlIsInstalled() -> Bool {
    FileManager.default.isReadableFile(atPath: CONFIG.ctlPath)
}

/// URL to open for "打开 DSH 网页".
///
/// dsh >= 0.1.7 gates the Web UI behind a per-process token: hitting
/// `http://127.0.0.1:3080/` bare returns **401**. `dsh-ctl.sh url` prints the token
/// URL harvested from the running process's log; the first visit trades it for a
/// 30-day cookie, after which the bare URL works again. We still fall back to the
/// bare URL so a pre-0.1.7 dsh (or an older `dsh-ctl.sh`) keeps working.
func resolvedWebURL() -> URL {
    let out = ctl("url").trimmingCharacters(in: .whitespacesAndNewlines)
    // `ctl` returns the script's stderr too, so only accept a line that really is a URL.
    for line in out.split(separator: "\n") {
        let candidate = line.trimmingCharacters(in: .whitespaces)
        if candidate.hasPrefix("http://"), let url = URL(string: candidate) { return url }
    }
    return URL(string: "http://127.0.0.1:\(CONFIG.port)/")!
}

/// Run an AppleScript snippet through osascript and return its stdout.
func runOsascript(_ script: String) -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    p.arguments = ["-e", script]
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = pipe
    do { try p.run() } catch { return "" }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

/// Raise an already-open DSH tab in Edge.
///
/// The Windows launcher solved this with a background poll server on port 9335 plus a
/// companion browser extension. macOS doesn't need any of that: Chromium browsers
/// expose their tabs to AppleScript, so we can select the right tab directly.
/// Uses numeric window/tab indices — `repeat with t in tabs` yields references, and
/// `index of t` then fails to coerce ("can't make index of ... into Unicode text").
/// Returns true when an existing tab was raised.
func raiseExistingDshTab() -> Bool {
    let script = """
    tell application "\(CONFIG.browser)"
        set wc to count of windows
        repeat with i from 1 to wc
            set tc to count of tabs of window i
            repeat with j from 1 to tc
                set u to URL of tab j of window i
                if u starts with "http://127.0.0.1:\(CONFIG.port)" then
                    set active tab index of window i to j
                    set index of window i to 1
                    activate
                    return "raised"
                end if
            end repeat
        end repeat
    end tell
    return "absent"
    """
    let out = runOsascript(script)
    // "absent" means Edge is running but has no DSH tab; anything empty means
    // Edge isn't running or Automation permission was refused.
    return out.contains("raised")
}

// MARK: - app delegate

final class WhaleDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var menu: NSMenu!
    var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = whaleIcon()
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(handleClick(_:))
            // Receive both buttons. Crucially we do NOT set statusItem.menu below:
            // attaching a menu makes AppKit swallow every click and open the menu.
            // Instead the action decides what to do, and we pop the menu up by hand.
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        menu = NSMenu()
        menu.delegate = self

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.updateIconState()
        }
        updateIconState()
    }

    /// Quitting the menu-bar app must also stop the DSH gateway. Otherwise port 3080
    /// keeps serving an orphan session after the whale leaves the menu bar.
    /// Covers every exit path (menu "退出大肥鱼", Cmd+Q, system logout).
    func applicationWillTerminate(_ notification: Notification) {
        _ = ctl("stop")
    }

    /// Left click = raise/jump to the DSH tab (the common case).
    /// Right click (or control-click) = the full menu.
    @objc func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp
            || (event?.modifierFlags.contains(.control) ?? false)

        if isRightClick {
            // Attach the menu only for this click so AppKit positions it exactly like
            // a native status-bar menu, then detach it again — otherwise every later
            // left click would open the menu instead of running our action.
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            openWeb()
        }
    }

    /// Load the whale PNG shipped in the bundle; fall back to an SF Symbol.
    func whaleIcon() -> NSImage? {
        let img: NSImage?
        if let path = Bundle.main.path(forResource: "whale", ofType: "png"),
           let loaded = NSImage(contentsOfFile: path) {
            img = loaded
        } else {
            img = NSImage(systemSymbolName: "fish.fill", accessibilityDescription: "DSH")
        }
        img?.size = NSSize(width: 19, height: 19)
        img?.isTemplate = false
        return img
    }

    /// Running = full colour; stopped = dimmed, so state is visible at a glance.
    func updateIconState() {
        let running = dshIsRunning()
        statusItem.button?.alphaValue = running ? 1.0 : 0.35
        if !ctlIsInstalled() {
            // A missing service script is the #1 reason a fresh copy "does nothing":
            // the menu opens, every action fails, and nothing says why.
            statusItem.button?.toolTip = """
            ⚠️ 找不到服务脚本
            \(CONFIG.ctlPath)
            把它放到该路径，或在 ~/.config/dsh-whale-tray/config.json 里设置 dshDir / ctlPath
            """
            return
        }
        statusItem.button?.toolTip = running
            ? "DSH 运行中 · 点击查看菜单"
            : "DSH 未运行 · 点击启动"
    }

    // Rebuild the menu each time it opens so it always reflects live state.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let running = dshIsRunning()

        let status = NSMenuItem(
            title: running ? "🐳 DSH 运行中  ·  http://127.0.0.1:\(CONFIG.port)" : "😴 DSH 未运行",
            action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        if !ctlIsInstalled() {
            let warn = NSMenuItem(
                title: "⚠️ 缺少 \(CONFIG.ctlPath)", action: nil, keyEquivalent: "")
            warn.isEnabled = false
            menu.addItem(warn)
        }

        menu.addItem(.separator())

        let toggle = NSMenuItem(
            title: running ? "关闭大肥鱼" : "开启大肥鱼",
            action: #selector(toggleDsh), keyEquivalent: "t")
        toggle.target = self
        menu.addItem(toggle)

        if running {
            let restart = NSMenuItem(title: "重启服务", action: #selector(restartDsh), keyEquivalent: "r")
            restart.target = self
            menu.addItem(restart)
        }

        let openWeb = NSMenuItem(title: "打开 DSH 网页", action: #selector(openWeb), keyEquivalent: "o")
        openWeb.target = self
        menu.addItem(openWeb)

        menu.addItem(.separator())

        let billing = NSMenuItem(title: CONFIG.billingLabel, action: #selector(openBilling), keyEquivalent: "")
        billing.target = self
        menu.addItem(billing)

        let quit = NSMenuItem(title: "退出大肥鱼", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    // MARK: actions

    @objc func toggleDsh() {
        let running = dshIsRunning()
        let out = ctl(running ? "stop" : "start")
        notify(running ? "已关闭大肥鱼" : "已开启大肥鱼", out)
        updateIconState()
    }

    @objc func restartDsh() {
        let out = ctl("restart")
        notify("已重启服务", out)
        updateIconState()
    }

    @objc func openWeb() {
        if !dshIsRunning() { _ = ctl("start") }
        updateIconState()
        // Prefer raising the tab the user already has, so clicking the whale doesn't
        // pile up duplicate DSH tabs. Falls back to opening one when there is none
        // (or when Automation permission for the browser hasn't been granted).
        if raiseExistingDshTab() { return }
        // Goes through `dsh-ctl.sh url`, which appends the per-process token that
        // dsh >= 0.1.7 requires — a bare URL is a 401 page there.
        NSWorkspace.shared.open(resolvedWebURL())
    }

    @objc func openBilling() {
        guard let url = URL(string: CONFIG.billingUrl) else {
            notify("充值链接无效", CONFIG.billingUrl)
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    func notify(_ title: String, _ body: String) {
        // Menu-bar apps have no window; surface the result of an action briefly.
        statusItem.button?.toolTip = "\(title): \(body.prefix(120))"
    }
}

// MARK: - entry point

// Debug hook: `WhaleLauncher --print-url` prints exactly what 打开网页 would open,
// then exits. When a fresh install lands on a 401 page this tells you in one line
// whether the token reached the launcher or the problem is in dsh-ctl.sh.
//   /Applications/大肥鱼.app/Contents/MacOS/WhaleLauncher --print-url
if CommandLine.arguments.contains("--print-url") {
    print("ctl    : \(CONFIG.ctlPath)  [\(ctlIsInstalled() ? "found" : "MISSING")]")
    print("port   : \(CONFIG.port)")
    print("browser: \(CONFIG.browser)")
    print("url    : \(resolvedWebURL().absoluteString)")
    exit(0)
}

let app = NSApplication.shared
let delegate = WhaleDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)   // no Dock icon
app.run()
