#!/bin/zsh
# DSH 权限体检 —— 确认这几项自动化权限是"真落地"而不是"看着像给了"。
#
#     zsh ~/DeepSeekHarness/bin/check-perms.sh
#
# 每一项都做一次真实调用,而不是只查 TCC 列表(我们也没权限读 TCC.db)。
export PATH="$HOME/.local/node/bin:/usr/bin:/bin:/usr/sbin:/sbin"

PASS=0; FAIL=0
HINTS=()
ok()   { printf "  ✅ %-14s %s\n" "$1" "$2"; PASS=$((PASS+1)); }
bad()  { printf "  ❌ %-14s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); printf "     └─ %s\n" "$3"; HINTS+=("$3"); }
note() { printf "  ── %-14s %s\n" "$1" "$2"; }

echo "DSH 权限体检  ($(date '+%H:%M:%S'))"
echo

# ---------------------------------------------------------------- 屏幕录制
# 文件名不能以 "." 开头 —— screencapture 拒绝写隐藏文件,看起来会像权限不足。
SHOT=/tmp/permcheck.png
rm -f "$SHOT"
if screencapture -x "$SHOT" >/dev/null 2>&1 && [ -s "$SHOT" ]; then
  SZ=$(stat -f%z "$SHOT")
  if [ "$SZ" -gt 20000 ]; then
    ok "屏幕录制" "截图 ${SZ} 字节"
  else
    bad "屏幕录制" "截出来是 ${SZ} 字节(疑似全黑)" \
        "系统设置 → 隐私与安全性 → 屏幕录制,勾上跑 DSH 的那个进程"
  fi
else
  bad "屏幕录制" "截图失败" "系统设置 → 隐私与安全性 → 屏幕录制"
fi
rm -f "$SHOT"

# ---------------------------------------------------------------- 自动化
EDGE=$(osascript -e 'tell application "Microsoft Edge" to get count of windows' 2>&1)
if echo "$EDGE" | grep -qE '^[0-9]+$'; then
  ok "自动化(Edge)" "拿到 Edge 窗口数 = $EDGE"
else
  bad "自动化(Edge)" "调用失败" "系统设置 → 隐私与安全性 → 自动化;正常会弹窗问一次"
fi

FINDER=$(osascript -e 'tell application "Finder" to get name of startup disk' 2>&1)
if [ "$FINDER" = "Macintosh HD" ]; then
  ok "自动化(Finder)" "启动盘 = $FINDER"
else
  bad "自动化(Finder)" "调用失败: $FINDER" "同上,自动化面板里勾 Finder"
fi

# ---------------------------------------------------------------- 辅助功能
# 必须用真正碰 UI 元素的调用 —— 只查进程列表不需要辅助功能,会假阳性。
AX=$(osascript -e 'tell application "System Events" to tell process "Finder" to get name of menu bar item 1 of menu bar 1' 2>&1)
if echo "$AX" | grep -q "不允许辅助访问\|not allowed assistive"; then
  bad "辅助功能" "被拒绝" \
      "面板里加 /usr/bin/osascript 和 $HOME/.local/node/bin/node,再把开关打开"
elif [ -n "$AX" ] && ! echo "$AX" | grep -qi "error\|execution error"; then
  ok "辅助功能" "能读到 Finder 菜单项 =「$AX」"
else
  bad "辅助功能" "返回异常: $AX" "面板里加 /usr/bin/osascript 和 node 两条"
fi

# ---------------------------------------------------------------- 完全磁盘访问
if sqlite3 "$HOME/Library/Application Support/com.apple.TCC/TCC.db" \
     "select count(*) from access;" >/dev/null 2>&1; then
  N=$(sqlite3 "$HOME/Library/Application Support/com.apple.TCC/TCC.db" "select count(*) from access;" 2>/dev/null)
  ok "完全磁盘访问" "能读 TCC.db($N 条授权记录)"
else
  bad "完全磁盘访问" "TCC.db 打不开(authorization denied)" \
      "面板里加 $HOME/.local/node/bin/node"
fi

if ls "$HOME/Library/Mail" >/dev/null 2>&1; then
  ok "受保护目录" "~/Library/Mail 可读"
else
  note "受保护目录" "~/Library/Mail 不可读(没有邮件账号时也会这样,不一定是权限问题)"
fi

# ---------------------------------------------------------------- 残留清理
WIDGET="$HOME/Library/Containers/local.dsh.whale.balance.widget"
if [ -e "$WIDGET" ]; then
  if rm -rf "$WIDGET" 2>/dev/null; then
    ok "残留清理" "已删掉 widget 残留(32K)"
  else
    bad "残留清理" "widget 残留还在,删不掉" "需要完全磁盘访问:加 $HOME/.local/node/bin/node"
  fi
else
  note "残留清理" "widget 残留已不在"
fi

# ---------------------------------------------------------------- 界面操作工具
if [ -x "$HOME/DeepSeekHarness/bin/uictl" ]; then
  T=$("$HOME/DeepSeekHarness/bin/uictl" trusted 2>/dev/null)
  if [ "$T" = "true" ]; then
    ok "界面操作" "uictl 可用(能合成点击/键盘)"
  else
    bad "界面操作" "uictl 存在但未获辅助功能" "面板里加 /usr/bin/osascript 或 $HOME/.local/node/bin/node"
  fi
else
  note "界面操作" "uictl 未编译(不是错误)"
fi

# ---------------------------------------------------------------- 汇总
echo
echo "  通过 $PASS 项,未通过 $FAIL 项"
if [ "$FAIL" -gt 0 ]; then
  echo
  echo "  待办(系统设置 → 隐私与安全性,点 + 号,按 Cmd+Shift+G 粘路径):"
  i=1
  for h in "${HINTS[@]}"; do
    echo "    $i) $h"
    i=$((i+1))
  done
  echo
  echo "  加完直接重跑本脚本即可复验,不需要重启 DSH。"
  exit 1
fi
echo "  自动化能力就绪。"
