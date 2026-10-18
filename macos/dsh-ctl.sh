#!/bin/zsh
# 大肥鱼 · macOS service layer
#
#   dsh-ctl.sh start|stop|restart|status|pid|url|open|billing|doctor
#
# Everything machine-specific comes from one optional JSON file, so *the same
# script* works on a machine where dsh lives somewhere else, listens on another
# port, or is opened in a different browser:
#
#   ~/.config/dsh-whale-tray/config.json        (or $DSH_WHALE_TRAY_CONFIG)
#
#   {
#     "dshDir":     "~/DeepSeekHarness",                  // where dsh is installed
#     "ctlPath":    "~/DeepSeekHarness/bin/dsh-ctl.sh",   // usually derived
#     "port":       3080,
#     "logPath":    "~/DeepSeekHarness/dsh-web.log",
#     "workdir":    "~/DeepSeekHarness/projects",
#     "browser":    "Microsoft Edge",
#     "billingUrl": "https://platform.deepseek.com/usage"
#   }
#
# Every key is optional and falls back to the value that works for a stock
# `~/DeepSeekHarness` install. Environment overrides win over the file:
#   DSH_DIR  DSH_PORT  DSH_LOG  DSH_BIN  DSH_WORKDIR  DSH_BROWSER  DSH_BILLING_URL
#
# Run `dsh-ctl.sh doctor` when something does not work — it prints exactly which
# piece it found, which it did not, and what to change.

CONFIG_FILE="${DSH_WHALE_TRAY_CONFIG:-$HOME/.config/dsh-whale-tray/config.json}"

# --- minimal JSON reader -----------------------------------------------------
# The config is a flat object of strings and integers, so sed is enough. Pulling in
# jq or python would turn "one script you can curl" into "one script + a dependency".
_cfg_str() {
  [ -r "$CONFIG_FILE" ] || return 0
  sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$CONFIG_FILE" | head -1
}
_cfg_int() {
  [ -r "$CONFIG_FILE" ] || return 0
  sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p" "$CONFIG_FILE" | head -1
}
_expand_tilde() { printf '%s' "${1/#\~/$HOME}" }

DSH_DIR="$(_expand_tilde "${DSH_DIR:-$(_cfg_str dshDir)}")"
[ -n "$DSH_DIR" ] || DSH_DIR="$HOME/DeepSeekHarness"

PORT="${DSH_PORT:-$(_cfg_int port)}"
[ -n "$PORT" ] || PORT=3080

BIN="${DSH_BIN:-$DSH_DIR/node_modules/.bin/dsh}"

LOG="$(_expand_tilde "${DSH_LOG:-$(_cfg_str logPath)}")"
[ -n "$LOG" ] || LOG="$DSH_DIR/dsh-web.log"

WORKDIR="$(_expand_tilde "${DSH_WORKDIR:-$(_cfg_str workdir)}")"
[ -n "$WORKDIR" ] || WORKDIR="$DSH_DIR/projects"

BROWSER="${DSH_BROWSER:-$(_cfg_str browser)}"
[ -n "$BROWSER" ] || BROWSER="Microsoft Edge"

BILLING_URL="${DSH_BILLING_URL:-$(_cfg_str billingUrl)}"
[ -n "$BILLING_URL" ] || BILLING_URL="https://platform.deepseek.com/usage"

export PATH="$HOME/.local/node/bin:$DSH_DIR/node_modules/.bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export DSH_HOME="${DSH_HOME:-$HOME/.dsh}"

dsh_pid() { /usr/sbin/lsof -nP -iTCP:$PORT -sTCP:LISTEN -t 2>/dev/null | head -1 }

# Prefer the profile-local binary; fall back to whatever `dsh` is on PATH.
_dsh_bin() {
  if [ -x "$BIN" ]; then printf '%s' "$BIN"; return 0; fi
  command -v dsh 2>/dev/null
}

# Newest token dsh printed at startup. dsh >= 0.1.7 requires it for the Web UI:
# bare http://127.0.0.1:PORT/ answers 401. The first tokenised visit trades the
# token for a 30-day cookie, after which the bare URL works again.
_web_token() {
  [ -r "$LOG" ] || return 0
  grep -o 'token=[A-Za-z0-9_-]*' "$LOG" 2>/dev/null | tail -1 | cut -d= -f2
}

_web_url() {
  local token
  token="$(_web_token)"
  if [ -n "$token" ]; then
    printf 'http://127.0.0.1:%s/?token=%s' "$PORT" "$token"
  else
    printf 'http://127.0.0.1:%s/' "$PORT"
  fi
}

_open_url() {
  open -a "$BROWSER" "$1" 2>/dev/null && return 0
  open "$1"
}

case "$1" in

  start)
    if [ -n "$(dsh_pid)" ]; then
      echo "already running (pid $(dsh_pid))"
      exit 0
    fi

    bin="$(_dsh_bin)"
    if [ -z "$bin" ]; then
      echo "找不到 dsh 可执行文件。" >&2
      echo "  期望路径：$BIN" >&2
      echo "  修法：在 $CONFIG_FILE 里写 {\"dshDir\": \"/你的/DeepSeekHarness\"}，或设 DSH_DIR。" >&2
      exit 1
    fi

    [ -d "$WORKDIR" ] || WORKDIR="$DSH_DIR"
    if [ ! -d "$WORKDIR" ]; then
      echo "找不到 dsh 目录：$DSH_DIR（改 config 的 dshDir）" >&2
      exit 1
    fi

    cd "$WORKDIR" || exit 1
    nohup "$bin" web --port "$PORT" --no-open >> "$LOG" 2>&1 &

    for i in {1..40}; do
      sleep 0.5
      if [ -n "$(dsh_pid)" ]; then
        echo "started (pid $(dsh_pid)) -> $(_web_url)"
        exit 0
      fi
    done
    echo "启动失败，最后 20 行日志（$LOG）：" >&2
    tail -20 "$LOG" >&2 2>/dev/null
    exit 1
    ;;

  stop)
    P=$(dsh_pid)
    if [ -z "$P" ]; then echo "not running"; exit 0; fi
    kill "$P" 2>/dev/null
    for i in {1..20}; do
      sleep 0.5
      [ -z "$(dsh_pid)" ] && { echo "stopped"; exit 0; }
    done
    kill -9 "$P" 2>/dev/null
    echo "force-stopped"
    ;;

  restart)
    "$0" stop
    sleep 1
    "$0" start
    ;;

  status)
    P=$(dsh_pid)
    if [ -n "$P" ]; then echo "running:$P"; else echo "stopped"; fi
    ;;

  pid)
    dsh_pid
    ;;

  url)
    # Single line, nothing else: the menu-bar app parses this verbatim.
    _web_url
    ;;

  open)
    if [ -z "$(dsh_pid)" ]; then "$0" start >/dev/null; fi
    URL="$(_web_url)"
    _open_url "$URL"
    echo "opened $URL"
    ;;

  billing)
    _open_url "$BILLING_URL"
    echo "$BILLING_URL"
    ;;

  doctor)
    # Answers "why doesn't it work on my machine?" without reading any source.
    echo "大肥鱼 · 环境体检"
    echo
    if [ -r "$CONFIG_FILE" ]; then
      echo "  配置文件   : $CONFIG_FILE  ✓"
    else
      echo "  配置文件   : （没有，全部走默认值）"
      echo "               $CONFIG_FILE"
    fi
    echo "  dsh 目录   : $DSH_DIR"
    if [ -d "$DSH_DIR" ]; then
      echo "               ✓ 存在"
    else
      echo "               ✗ 不存在 → 改 config 的 dshDir"
    fi
    bin="$(_dsh_bin)"
    if [ -n "$bin" ]; then
      echo "  dsh 可执行 : $bin"
    else
      echo "  dsh 可执行 : ✗ 找不到 → 改 dshDir，或先安装 dsh"
    fi
    echo "  工作目录   : $WORKDIR"
    if [ -r "$LOG" ]; then
      echo "  日志       : $LOG  ✓"
    else
      echo "  日志       : $LOG  ✗ 读不到 → token 会取不到"
    fi
    echo "  端口       : $PORT"
    P=$(dsh_pid)
    if [ -n "$P" ]; then echo "               运行中（pid $P）"; else echo "               未运行"; fi
    if [ -n "$(_web_token)" ]; then
      echo "  token      : ✓ 已从日志取到（dsh >= 0.1.7 必需）"
    else
      echo "  token      : ✗ 没取到 —— dsh < 0.1.7 不需要；否则说明日志里还没有启动行"
    fi
    echo "  浏览器     : $BROWSER"
    echo "  账单页     : $BILLING_URL"
    echo "  打开地址   : $(_web_url)"
    ;;

  *)
    echo "usage: dsh-ctl.sh start|stop|restart|status|pid|url|open|billing|doctor" >&2
    exit 2
    ;;
esac
