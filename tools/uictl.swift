// uictl —— DSH 的界面操作小工具(合成鼠标/键盘事件、读光标位置)。
//
// 为什么需要它:DSH 的 bash 工具能跑命令,但没法点按钮、敲键盘。这个二进制从 node
// 进程链上派生,因此继承 DSH 已有的【辅助功能】授权,可以真的操作界面。
//
//     swiftc -sdk <SDK> -O -o ~/DeepSeekHarness/bin/uictl uictl.swift \
//            -framework AppKit -framework ApplicationServices
//
// 用法:
//     uictl pos                       打印光标位置
//     uictl move X Y                  移动光标
//     uictl click X Y [left|right]    单击(默认左键),坐标是屏幕逻辑坐标
//     uictl dblclick X Y              双击
//     uictl type "文本"               输入文本(走 Unicode,支持中文)
//     uictl key <keycode> [mods]      按键,mods 用逗号分隔:cmd,shift,alt,ctrl
//     uictl trusted                   打印辅助功能是否已授权
//
// 坐标原点在【左上角】,与 System Events / screencapture 一致。
import AppKit
import ApplicationServices
import CoreGraphics

let args = Array(CommandLine.arguments.dropFirst())

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
    exit(2)
}

func post(_ e: CGEvent?) {
    guard let e else { return }
    e.post(tap: .cghidEventTap)
}

let src = CGEventSource(stateID: .hidSystemState)
let loc = CGEvent(source: nil)?.location ?? .zero

guard let cmd = args.first else {
    fail("""
    usage: uictl pos | move X Y | click X Y [left|right] | dblclick X Y | \
    type TEXT | key KEYCODE [cmd,shift,alt,ctrl] | trusted
    """)
}

switch cmd {
case "trusted":
    print(AXIsProcessTrusted() ? "true" : "false")

case "pos":
    print("\(Int(loc.x)) \(Int(loc.y))")

case "move":
    guard args.count >= 3, let x = Double(args[1]), let y = Double(args[2]) else { fail("move 需要 X Y") }
    post(CGEvent(mouseEventSource: src, mouseType: .mouseMoved,
                 mouseCursorPosition: CGPoint(x: x, y: y), mouseButton: .left))

case "click", "dblclick":
    guard args.count >= 3, let x = Double(args[1]), let y = Double(args[2]) else { fail("click 需要 X Y") }
    let right = args.count >= 4 && args[3].lowercased() == "right"
    let p = CGPoint(x: x, y: y)
    // 先移动再按下:菜单栏图标这类控件要靠 mouseEntered 才会点亮
    post(CGEvent(mouseEventSource: src, mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left))
    usleep(120_000)
    let down: CGEventType = right ? .rightMouseDown : .leftMouseDown
    let up: CGEventType = right ? .rightMouseUp : .leftMouseUp
    let btn: CGMouseButton = right ? .right : .left
    let times = cmd == "dblclick" ? 2 : 1
    for _ in 0..<times {
        post(CGEvent(mouseEventSource: src, mouseType: down, mouseCursorPosition: p, mouseButton: btn))
        usleep(60_000)
        post(CGEvent(mouseEventSource: src, mouseType: up, mouseCursorPosition: p, mouseButton: btn))
        if times > 1 { usleep(60_000) }
    }

case "type":
    guard args.count >= 2 else { fail("type 需要文本") }
    let text = args[1]
    for scalar in text.unicodeScalars {
        var buf = [UniChar(scalar.value)]
        if let down = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true) {
            down.keyboardSetUnicodeString(stringLength: 1, unicodeString: &buf)
            post(down)
        }
        if let up = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false) {
            up.keyboardSetUnicodeString(stringLength: 1, unicodeString: &buf)
            post(up)
        }
        usleep(12_000)
    }

case "key":
    guard args.count >= 2, let code = UInt16(args[1]) else { fail("key 需要 keycode 数字") }
    var flags: CGEventFlags = []
    if args.count >= 3 {
        for m in args[2].lowercased().split(separator: ",") {
            switch m {
            case "cmd", "command": flags.insert(.maskCommand)
            case "shift":          flags.insert(.maskShift)
            case "alt", "opt":     flags.insert(.maskAlternate)
            case "ctrl", "control":flags.insert(.maskControl)
            default: fail("未知修饰键: \(m)")
            }
        }
    }
    if let down = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true) {
        down.flags = flags; post(down)
    }
    if let up = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false) {
        up.flags = flags; post(up)
    }

default:
    fail("未知命令: \(cmd)")
}
