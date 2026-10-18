#!/bin/zsh
# 大肥鱼 · macOS 一键安装
#
#   curl -fsSL https://raw.githubusercontent.com/zhqowo/dsh-whale-tray/main/macos/install.sh | zsh
#
# 它会做四件事，每一步都打印出来，任何一步失败都会停下并说明原因：
#   1. 找到你的 dsh 装在哪（找不到就用 --dir 指定）
#   2. 装菜单栏 app（默认从 Release 下载；--build 则本机编译）
#   3. 装服务脚本 dsh-ctl.sh 到 <dshDir>/bin/
#   4. 写配置 ~/.config/dsh-whale-tray/config.json
#
# 选项：
#   --dir <path>        dsh 安装根目录（如 ~/DeepSeekHarness）
#   --dest <dir>        app 装到哪（默认 ~/Applications）
#   --port <n>          端口，默认 3080
#   --browser <name>    浏览器，默认 "Microsoft Edge"（可写 "Google Chrome"）
#   --build             本机编译，不从 Release 下载（需要 Xcode Command Line Tools）
#   --no-app            只装服务脚本 + 配置，不装菜单栏 app
#   --no-ctl            不安装 / 不更新 dsh-ctl.sh
#   --yes               不提问，全部用默认值
#
# 卸载：删掉 ~/Applications/大肥鱼.app 和 ~/.config/dsh-whale-tray/ 即可。

set -e

RAW="https://raw.githubusercontent.com/zhqowo/dsh-whale-tray/main"
REPO="https://github.com/zhqowo/dsh-whale-tray"

# 脚本自身位置。用 curl | zsh 跑的时候这里为空，于是所有文件都从 GitHub 取。
SELF="${(%):-%x}"
HERE=""
[ -f "$SELF" ] && HERE="$(cd "$(dirname "$SELF")" && pwd)"

DEST=""    # 空 = 自动：/Applications 可写就装那儿，否则退回 ~/Applications
DSH_DIR=""
PORT="3080"
BROWSER="Microsoft Edge"
DO_BUILD=0
DO_APP=1
DO_CTL=1
ASSUME_YES=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dir)      DSH_DIR="$2"; shift 2 ;;
    --dest)     DEST="$2"; shift 2 ;;
    --port)     PORT="$2"; shift 2 ;;
    --browser)  BROWSER="$2"; shift 2 ;;
    --build)    DO_BUILD=1; shift ;;
    --no-app)   DO_APP=0; shift ;;
    --no-ctl)   DO_CTL=0; shift ;;
    --yes|-y)   ASSUME_YES=1; shift ;;
    -h|--help)  sed -n '2,28p' "$SELF" 2>/dev/null || echo "见 $REPO"; exit 0 ;;
    *)          echo "未知参数：$1（--help 看用法）" >&2; exit 2 ;;
  esac
done

# /Applications 一般管理员可写；退而求其次装到 ~/Applications（启动台一样能看到）。
if [ -z "$DEST" ]; then
  if [ -w /Applications ]; then DEST="/Applications"; else DEST="$HOME/Applications"; fi
fi

ok()   { printf '  \033[32m✓\033[0m %s\n' "$1" }
info() { printf '  · %s\n' "$1" }
warn() { printf '  \033[33m!\033[0m %s\n' "$1" }
die()  { printf '\n  \033[31m✗ %s\033[0m\n\n' "$1" >&2; exit 1; }

echo
echo "🐳 大肥鱼 · macOS 安装"
echo

# ---------------------------------------------------------------- 1. 找 dsh
echo "[1/4] 定位 dsh"

if [ -z "$DSH_DIR" ] && [ -n "${DSH_DIR_OVERRIDE:-}" ]; then DSH_DIR="$DSH_DIR_OVERRIDE"; fi

_candidates=()
[ -n "$DSH_DIR" ] && _candidates+=("$DSH_DIR")
_candidates+=("$HOME/DeepSeekHarness")
# PATH 上的 dsh：node_modules/.bin/dsh -> 上两级就是安装根目录
if _which=$(command -v dsh 2>/dev/null); then
  _candidates+=("$(cd "$(dirname "$_which")/../.." 2>/dev/null && pwd || true)")
fi

for c in "${_candidates[@]}"; do
  [ -z "$c" ] && continue
  c="${c/#\~/$HOME}"
  if [ -x "$c/node_modules/.bin/dsh" ]; then DSH_DIR="$c"; break; fi
done

if [ -z "$DSH_DIR" ] || [ ! -x "$DSH_DIR/node_modules/.bin/dsh" ]; then
  echo
  die "没找到 dsh。它不在 ~/DeepSeekHarness，也不在 PATH 上。
      用 --dir 指定安装根目录，例如：
        sh install.sh --dir ~/code/DeepSeekHarness
      目录里应当有 node_modules/.bin/dsh。"
fi
ok "dsh 在 $DSH_DIR"

mkdir -p "$DSH_DIR/bin"

# ---------------------------------------------------------------- 2. 装 app
echo "[2/4] 安装菜单栏 app"

APP="$DEST/大肥鱼.app"

if [ "$DO_APP" = "0" ]; then
  info "跳过（--no-app）：只装服务脚本，用命令行启动即可"
else
  mkdir -p "$DEST"

  if [ -d "$APP" ] && [ "$ASSUME_YES" = "0" ]; then
    echo
    printf "  %s 已存在，覆盖？[y/N] " "$APP"
    read -r _ans
    case "$_ans" in [yY]*) ;; *) die "已取消（没有改动任何文件）" ;; esac
  fi

  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT

  if [ "$DO_BUILD" = "1" ]; then
    [ -n "$HERE" ] && [ -f "$HERE/build.sh" ] || die "--build 需要仓库源码：先 git clone $REPO，再在 macos/ 里运行本脚本"
    info "本机编译（需要 Xcode Command Line Tools）..."
    WHALE_APP_OUT="$TMP/大肥鱼.app" zsh "$HERE/build.sh" >/dev/null || die "编译失败"
    SRC="$TMP/大肥鱼.app"
  else
    info "下载 Release ..."
    ZIP="$TMP/DaFeiYu.app.zip"
    if ! curl -fsSL --connect-timeout 20 "$REPO/releases/latest/download/DaFeiYu.app.zip" -o "$ZIP"; then
      echo
      die "下载失败。手动下载再装：
        $REPO/releases/latest
      解开后把 大肥鱼.app 拖进 $DEST 即可。"
    fi
    /usr/bin/ditto -x -k "$ZIP" "$TMP/x" || die "解压失败"
    SRC="$(/bin/ls -d "$TMP"/x/*.app 2>/dev/null | head -1)"
    [ -n "$SRC" ] || die "压缩包里没找到 .app"
  fi

  rm -rf "$APP"
  /bin/cp -R "$SRC" "$APP"
  # ad-hoc 签名 + 从网络下载 -> Gatekeeper 会拦。去掉隔离标记，和右键「打开」等效。
  /usr/bin/xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" 2>/dev/null || true
  ok "已装到 $APP"
fi

# ---------------------------------------------------------------- 3. 装脚本
echo "[3/4] 安装服务脚本"

CTL="$DSH_DIR/bin/dsh-ctl.sh"
if [ "$DO_CTL" = "0" ]; then
  info "跳过（--no-ctl）"
elif [ -n "$HERE" ] && [ -f "$HERE/dsh-ctl.sh" ]; then
  /bin/cp "$HERE/dsh-ctl.sh" "$CTL"
  chmod +x "$CTL"
  ok "已装到 $CTL"
else
  if curl -fsSL --connect-timeout 20 "$RAW/macos/dsh-ctl.sh" -o "$CTL"; then
    chmod +x "$CTL"
    ok "已装到 $CTL"
  else
    warn "下载 dsh-ctl.sh 失败；app 会因为找不到脚本而报警"
  fi
fi

# ---------------------------------------------------------------- 4. 写配置
echo "[4/4] 写配置"

CFG_DIR="$HOME/.config/dsh-whale-tray"
CFG="$CFG_DIR/config.json"
mkdir -p "$CFG_DIR"

if [ -f "$CFG" ]; then
  info "已有 $CFG，保留不动（要改就手动编辑）"
else
  cat > "$CFG" <<JSON
{
  "dshDir": "$DSH_DIR",
  "port": $PORT,
  "browser": "$BROWSER",
  "billingUrl": "https://platform.deepseek.com/usage"
}
JSON
  ok "已写 $CFG"
fi

# ---------------------------------------------------------------- 体检
echo
echo "🩺 体检"
echo
zsh "$CTL" doctor 2>/dev/null || true

echo
echo "✅ 装完了"
echo
echo "接下来："
if [ "$DO_APP" = "1" ]; then
  echo "  1. 打开    $APP"
  echo "     首次点「打开网页」会弹「大肥鱼 想要控制 $BROWSER」→ 点允许"
  echo "     （拒绝也能用，只是每次新开标签而不是切到已开的）"
  echo "  2. 菜单栏出现鲸鱼：左键切标签 / 右键弹菜单"
  echo "  3. 出问题先跑：$CTL doctor"
else
  echo "  1. 命令行：$CTL start|stop|restart|open|doctor"
  echo "  2. 想更省事，可以在「快捷指令」里建一个「运行 Shell 脚本」的动作指向它"
  echo "  3. 出问题先跑：$CTL doctor"
fi
echo "  4. 想改端口 / 浏览器 / 安装位置 → $CFG"
echo
echo "⚠️  TCC 权限的坑（尤其\"DSH 由谁启动\"）见："
echo "    $REPO/blob/main/macos/README.md"
echo
