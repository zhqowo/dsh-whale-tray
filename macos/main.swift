// 大肥鱼 — macOS menu-bar launcher for DeepSeek Harness.
// The macOS counterpart of the Windows tray app: a whale icon living in the
// menu bar, showing service state and offering start/stop/restart/open/billing.
import Cocoa

let PORT: UInt16 = 3080
let HOME = NSHomeDirectory()
let CTL = "\(HOME)/DeepSeekHarness/bin/dsh-ctl.sh"

// MARK: - helpers

/// Cheap liveness probe: try a TCP connect to the dsh web port.
func dshIsRunning() -> Bool {
    let sock = socket(AF_INET, SOCK_STREAM, 0)
    if sock < 0 { return false }
    defer { close(sock) }

    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = PORT.bigEndian
    addr.sin_addr.s_addr = inet_addr("127.0.0.1")
    addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)

    let rc = withUnsafePointer(to: &addr) { ptr in
        ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
            connect(sock, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    return rc == 0
}

/// Run a shell command with a PATH that can find node/pnpm.
@discardableResult
func shell(_ args: [String]) -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/zsh")
    p.arguments = ["-lc", args.joined(separator: " ")]
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

func ctl(_ arg: String) -> String { shell([CTL, arg]) }

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
    tell application "Microsoft Edge"
        set wc to count of windows
        repeat with i from 1 to wc
            set tc to count of tabs of window i
            repeat with j from 1 to tc
                set u to URL of tab j of window i
                if u starts with "http://127.0.0.1:\(PORT)" then
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
        statusItem.button?.toolTip = running
            ? "DSH 运行中 · 点击查看菜单"
            : "DSH 未运行 · 点击启动"
    }

    // Rebuild the menu each time it opens so it always reflects live state.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let running = dshIsRunning()

        let status = NSMenuItem(
            title: running ? "🐳 DSH 运行中  ·  http://127.0.0.1:\(PORT)" : "😴 DSH 未运行",
            action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
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

        let billing = NSMenuItem(title: "充值", action: #selector(openBilling), keyEquivalent: "")
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
        // (or when Automation permission for Edge hasn't been granted).
        if raiseExistingDshTab() { return }
        NSWorkspace.shared.open(URL(string: "http://127.0.0.1:\(PORT)/")!)
    }

    @objc func openBilling() {
        NSWorkspace.shared.open(URL(string: "https://platform.deepseek.com/usage")!)
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

let app = NSApplication.shared
let delegate = WhaleDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)   // no Dock icon
app.run()
