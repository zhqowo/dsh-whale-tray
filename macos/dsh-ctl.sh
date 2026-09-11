#!/bin/zsh
# dsh service control on macOS (macOS port of the "大肥鱼" launcher's service layer).
# Usage: dsh-ctl.sh start|stop|restart|status|open|pid
export PATH="$HOME/.local/node/bin:$PATH"
export DSH_HOME="$HOME/.dsh"

DIR="$HOME/DeepSeekHarness"
BIN="$DIR/node_modules/.bin/dsh"
LOG="$DIR/dsh-web.log"
PORT=3080

dsh_pid() {
  /usr/sbin/lsof -nP -iTCP:$PORT -sTCP:LISTEN -t 2>/dev/null | head -1
}

case "$1" in
  start)
    if [ -n "$(dsh_pid)" ]; then
      echo "already running (pid $(dsh_pid))"
      exit 0
    fi
    cd "$DIR/projects" || exit 1
    nohup "$BIN" web --port $PORT --no-open >> "$LOG" 2>&1 &
    for i in {1..40}; do
      sleep 0.5
      if [ -n "$(dsh_pid)" ]; then
        echo "started (pid $(dsh_pid)) -> http://127.0.0.1:$PORT"
        exit 0
      fi
    done
    echo "FAILED to start; see $LOG"
    tail -20 "$LOG"
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
  open)
    # Raise an existing DSH tab if the browser already has one, else open a new tab.
    if [ -z "$(dsh_pid)" ]; then "$0" start >/dev/null; fi
    open -a "Microsoft Edge" "http://127.0.0.1:$PORT/" 2>/dev/null \
      || open "http://127.0.0.1:$PORT/"
    echo "opened http://127.0.0.1:$PORT/"
    ;;
  billing)
    open -a "Microsoft Edge" "https://platform.deepseek.com/usage" 2>/dev/null \
      || open "https://platform.deepseek.com/usage"
    ;;
  *)
    echo "usage: dsh-ctl.sh start|stop|restart|status|pid|open|billing"
    exit 2
    ;;
esac
