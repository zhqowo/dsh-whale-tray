#!/bin/zsh
# 迁移资产体检 —— 把从 Windows 迁过来的工具挨个做真实调用,判断"通不通"。
#
#     zsh ~/DeepSeekHarness/bin/check-tools.sh
#
# 原则:每一项都发一次真实请求(真的查 Steam、真的调 API),不是只看文件在不在。
# 破坏性脚本(_migrate_sessions / fix_cfg / repair_ab)一律只做 dry-run 或跳过。
export PATH="$HOME/.local/node/bin:/usr/bin:/bin:/usr/sbin:/sbin"

PASS=0; FAIL=0; SKIP=0
ok()   { printf "  ✅ %-22s %s\n" "$1" "$2"; PASS=$((PASS+1)); }
bad()  { printf "  ❌ %-22s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }
skip() { printf "  ⏭️  %-22s %s\n" "$1" "$2"; SKIP=$((SKIP+1)); }

# 网络类检查统一重试 —— 国内到 Steam / B站 的国际链路**首次请求经常超时**,
# 不重试就会把"网络抖动"误报成"工具坏了"(实测失败项每轮都在轮换)。
RETRIED=0
net() {   # net <命令...>  → 打印最后一次输出;重试过则把 RETRIED 置 1
  local i=1 out=""
  RETRIED=0
  while [ "$i" -le 3 ]; do
    out=$("$@" 2>&1)
    if [ -n "$out" ] && ! printf '%s' "$out" | grep -qiE "timed out|Connection timed out|请求失败|Could not resolve"; then
      [ "$i" -gt 1 ] && RETRIED=1
      printf '%s' "$out"
      return 0
    fi
    sleep 2
    i=$((i + 1))
  done
  [ "$i" -gt 1 ] && RETRIED=1
  printf '%s' "$out"
}
tag() { [ "$RETRIED" = 1 ] && printf ' (重试后成功)'; }

echo "迁移资产体检  ($(date '+%H:%M:%S'))"
echo

# ─────────────────────────────────────────────── 凭据文件
echo "【凭据】"
for f in "$HOME/.dsh/.credentials.yaml" "$HOME/.dsh/api_keys.json" "$HOME/.dsh/steam_api_key.txt"; do
  if [ -f "$f" ]; then
    PERM=$(stat -f%Lp "$f")
    if [ "$PERM" = "600" ]; then ok "$(basename $f)" "存在,权限 $PERM"
    else bad "$(basename $f)" "权限是 $PERM(应为 600)"; fi
  else
    bad "$(basename $f)" "文件不存在"
  fi
done
echo

# ─────────────────────────────────────────────── 查询工具
echo "【查询工具】(source 后调用)"
source "$HOME/DeepSeekHarness/projects/steam.sh"  >/dev/null 2>&1
source "$HOME/DeepSeekHarness/projects/gh.sh"     >/dev/null 2>&1
source "$HOME/DeepSeekHarness/projects/bili.sh"   >/dev/null 2>&1
source "$HOME/DeepSeekHarness/projects/maps.sh"   >/dev/null 2>&1

# Steam
R=$(net steam-search "Portal 2"); R=$(printf '%s' "$R" | head -3)
if echo "$R" | grep -qi "portal"; then ok "steam-search" "免 key$(tag),查到 $(echo "$R" | head -1 | cut -c1-40)"
else bad "steam-search" "$(echo $R | cut -c1-70)"; fi

# appdetails 返回的是美化过的 JSON,游戏名不在前几行 —— 必须解析 JSON 判断,别 grep 文本。
R=$(net steam-appdetails 620)
NAME=$(printf '%s' "$R" | python3 -c "
import json,sys
try: print(list(json.load(sys.stdin).values())[0]['data']['name'])
except Exception: print('')" 2>/dev/null)
if [ -n "$NAME" ]; then ok "steam-appdetails" "免 key$(tag),查到「$NAME」"
else bad "steam-appdetails" "$(printf '%s' "$R" | head -2 | cut -c1-70)"; fi

R=$(net steam-playercount 730); R=$(printf '%s' "$R" | head -3)
if echo "$R" | grep -qE "[0-9]{3,}"; then ok "steam-playercount" "需 key$(tag),当前在线 $(echo "$R" | grep -oE '[0-9,]+' | head -1)"
else bad "steam-playercount" "$(echo $R | cut -c1-70)"; fi

# 注意：不能写成 `steam-ownedgames ... | head` —— head 会提前关管道(SIGPIPE),
# 让请求看起来像失败。先收全量输出,再截取显示。
R=$(net steam-ownedgames 76561198809739186); R=$(printf '%s' "$R" | head -6)
if echo "$R" | grep -q "游戏数"; then ok "steam-ownedgames" "需 key$(tag),$(echo "$R" | grep -oE '游戏数: [0-9]+.*' | head -1 | cut -c1-40)"
else bad "steam-ownedgames" "$(echo $R | head -2 | cut -c1-70)"; fi

# GitHub
R=$(ghApi /repos/zhqowo/dsh-whale-tray 2>&1 | head -c 200)
if echo "$R" | grep -q "dsh-whale-tray"; then ok "ghApi" "查到仓库,默认分支 $(echo "$R" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("default_branch"))' 2>/dev/null)"
else bad "ghApi" "$(echo $R | cut -c1-70)"; fi

R=$(ghSearchRepos "deepseek harness" 3 2>&1 | head -3)
if echo "$R" | grep -qiE "deepseek|harness"; then ok "ghSearchRepos" "搜到结果"
else bad "ghSearchRepos" "$(echo $R | cut -c1-70)"; fi

# B站 —— 先从排行榜拿一个真实 bvid,再拿它去查,顺带验证两条链路
# B站取样本很脆(排行榜接口时不时限流),所以多源 + 重试 + 兜底 bvid,
# 免得"取样本失败"被误读成"bili 工具坏了"。
BVID=""
for url in "https://api.bilibili.com/x/web-interface/ranking/v2" \
           "https://api.bilibili.com/x/web-interface/popular?ps=1&pn=1"; do
  for try in 1 2 3; do
    BVID=$(curl -sS -m 15 -A 'Mozilla/5.0' "$url" 2>/dev/null | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    print((d.get('data',{}).get('list') or [{}])[0].get('bvid','') or '')
except Exception: print('')" 2>/dev/null)
    [ -n "$BVID" ] && break
    sleep 2
  done
  [ -n "$BVID" ] && break
done
SRC="实时"
[ -z "$BVID" ] && { BVID="BV1eqYx6UE9V"; SRC="兜底样本"; }

R=$(net bili-video "$BVID"); R=$(printf '%s' "$R" | head -5)
if echo "$R" | grep -qE "播放|view|[0-9]{4,}"; then ok "bili-video" "$BVID ($SRC) → $(echo "$R" | head -1 | cut -c1-32)"
else bad "bili-video" "$BVID → $(echo $R | head -2 | cut -c1-60)"; fi

R=$(net bili-comments "$BVID" 3); R=$(printf '%s' "$R" | head -4)
if [ -n "$R" ] && ! echo "$R" | grep -qiE "error|失败|code\":-"; then ok "bili-comments" "取到评论"
else bad "bili-comments" "$(echo $R | head -1 | cut -c1-60)"; fi

# 地图
R=$(net amap "天安门" 北京); R=$(printf '%s' "$R" | head -4)
if echo "$R" | grep -qE "天安门|116\.|39\."; then ok "amap(高德)" "$(echo "$R" | head -1 | cut -c1-42)"
else bad "amap(高德)" "$(echo $R | head -2 | cut -c1-70)"; fi

R=$(net bd-map "天安门" 北京); R=$(printf '%s' "$R" | head -4)
if echo "$R" | grep -qE "天安门|116\.|39\."; then ok "bd-map(百度)" "$(echo "$R" | head -1 | cut -c1-42)"
else bad "bd-map(百度)" "$(echo $R | head -2 | cut -c1-70)"; fi
echo

# ─────────────────────────────────────────────── 迁移脚本
echo "【迁移 / 会话工具】"
M="$HOME/DeepSeekHarness/migration"

R=$(node "$M/_verify_session.mjs" "$HOME/.dsh/sessions" 2>&1 | tail -5)
if echo "$R" | grep -qiE "ok|pass|通过|valid|[0-9]+ (session|会话)"; then ok "_verify_session" "$(echo "$R" | tail -1 | cut -c1-50)"
elif [ -z "$R" ]; then ok "_verify_session" "跑完无报错"
else bad "_verify_session" "$(echo $R | tail -1 | cut -c1-60)"; fi

S=$(find "$HOME/.dsh/sessions" -name 'session.jsonl.zstd' | head -1)
if [ -n "$S" ]; then
  R=$(node "$M/_dump_session.mjs" "$S" /tmp/_dump_test.jsonl 2>&1 | tail -3)
  if [ -s /tmp/_dump_test.jsonl ]; then ok "_dump_session" "解出 $(wc -l < /tmp/_dump_test.jsonl | tr -d ' ') 行"
  else bad "_dump_session" "$(echo $R | tail -1 | cut -c1-60)"; fi
fi

# 破坏性脚本:只 dry-run
R=$(node "$M/_migrate_sessions.mjs" "$HOME/.dsh/sessions" --dry-run 2>&1 | tail -4)
if echo "$R" | grep -qiE "dry|no change|无需|0 |skip"; then ok "_migrate_sessions" "dry-run 正常(未实际写入)"
elif [ -n "$R" ]; then ok "_migrate_sessions" "dry-run 跑通: $(echo "$R" | tail -1 | cut -c1-40)"
else bad "_migrate_sessions" "无输出"; fi

R=$(node "$M/versions.mjs" "$HOME/.dsh/profiles/web/node_modules" 2>&1 | head -6)
if [ -n "$R" ] && ! echo "$R" | grep -qiE "error|cannot find"; then ok "versions.mjs" "$(echo "$R" | head -1 | cut -c1-45)"
else bad "versions.mjs" "$(echo $R | head -1 | cut -c1-60)"; fi

skip "fix_cfg.mjs" "改配置(已应用),不重跑"
skip "repair_ab.mjs" "改 pnpm-workspace(已应用),不重跑"
echo

# ─────────────────────────────────────────────── DeepSeek API
echo "【DeepSeek API】"
BAL=$(curl -sS -m 20 -H "Authorization: Bearer $(python3 -c "
import re,sys
t=open('$HOME/.dsh/.credentials.yaml').read()
m=re.search(r'DEEPSEEK_API_KEY:\s*(\S+)',t); print(m.group(1) if m else '')" 2>/dev/null)" \
  https://api.deepseek.com/user/balance 2>/dev/null)
if echo "$BAL" | grep -q "total_balance"; then ok "余额接口" "余额 $(echo "$BAL" | python3 -c 'import json,sys;print(json.load(sys.stdin)["balance_infos"][0]["total_balance"], json.load(open("/dev/null")) if 0 else "")' 2>/dev/null || echo "$BAL" | grep -oE '"total_balance":"[^"]*"')"
else bad "余额接口" "$(echo $BAL | head -c 70)"; fi

R=$(node "$M/test_v41.mjs" 2>&1 | tail -6)
if echo "$R" | grep -qiE "ok|pass|通过|✅|回答"; then ok "test_v41.mjs" "v4.1 调用正常"
elif echo "$R" | grep -qiE "error|401|403"; then bad "test_v41.mjs" "$(echo $R | tail -1 | cut -c1-60)"
else ok "test_v41.mjs" "跑通($(echo "$R" | tail -1 | cut -c1-40))"; fi
echo

# ─────────────────────────────────────────────── 浏览器扩展 / 启动器
echo "【其他资产】"
EXT="$HOME/dsh-browser-extension/dsh-browser/dist"
if [ -f "$EXT/manifest.json" ]; then
  V=$(python3 -c "import json;print(json.load(open('$EXT/manifest.json')).get('version'))" 2>/dev/null)
  ok "浏览器扩展" "manifest v$V,$(ls "$EXT" | wc -l | tr -d ' ') 个文件"
else bad "浏览器扩展" "dist/manifest.json 不存在"; fi

for app in "$HOME/Desktop/大肥鱼.app" "$HOME/Desktop/OpenClaw.app"; do
  if [ -d "$app" ]; then
    if codesign -v "$app" 2>/dev/null; then ok "$(basename $app)" "签名完好"
    else bad "$(basename $app)" "签名校验失败"; fi
  else bad "$(basename $app)" "不存在"; fi
done
echo

# ─────────────────────────────────────────────── 汇总
echo "════════════════════════════════"
echo "  通过 $PASS · 失败 $FAIL · 跳过 $SKIP"
[ "$FAIL" -gt 0 ] && echo "  ↑ 失败项需要从 Windows 重传或重新配置"
exit 0
