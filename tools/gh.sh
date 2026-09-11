#!/bin/bash
# gh.sh -- GitHub 工具 (macOS/Linux 版, 对齐 Windows 的 gh.ps1)
# 用法: source ~/DeepSeekHarness/projects/gh.sh
#   ghSearchRepos "dsh plugin" 5 --sort-stars
#   ghApi /repos/owner/repo
#   ghRaw https://raw.githubusercontent.com/...
#   ghMe / ghRate                      # 认证状态
#   ghReleaseCreate owner/repo v1.0 "标题" "说明" file1 file2
#
# 认证：自动读 ~/.dsh/github_token（或环境变量 $GITHUB_TOKEN）。
# 有 token → 5000 次/小时 且能写；没有 → 匿名 60 次/小时 只读。两者都能用。

GH_UA='dsh-gh-helper/1.0'
GH_TOKEN_FILE="$HOME/.dsh/github_token"

_gh_token() {
  if [ -n "$GITHUB_TOKEN" ]; then printf '%s' "$GITHUB_TOKEN"; return 0; fi
  if [ -f "$GH_TOKEN_FILE" ]; then tr -d '\r\n' < "$GH_TOKEN_FILE"; return 0; fi
  printf ''
}

# 统一的 curl 包装：有 token 就带上 Authorization。注意 URL 放最后，
# 额外参数($@)插在 URL 前面，curl 对选项位置不敏感。
_gh_curl() {
  local gh_url="$1"; shift
  local gh_tok
  gh_tok=$(_gh_token)
  if [ -n "$gh_tok" ]; then
    curl -sS -m 30 -A "$GH_UA" -H "Authorization: Bearer $gh_tok" "$@" "$gh_url"
  else
    curl -sS -m 30 -A "$GH_UA" "$@" "$gh_url"
  fi
}

ghApi() {
  local gh_path="$1"
  local gh_tries="${2:-5}"
  local gh_i=1
  local gh_out="" gh_code="" gh_body=""
  while [ "$gh_i" -le "$gh_tries" ]; do
    gh_out=$(_gh_curl "https://api.github.com${gh_path}" \
      -H 'Accept: application/vnd.github+json' -w 'HTTPSTATUS:%{http_code}')
    if [ -z "$gh_out" ]; then
      sleep "$gh_i"
      gh_i=$((gh_i + 1))
      continue
    fi
    gh_code=$(printf '%s' "$gh_out" | sed -n 's/.*HTTPSTATUS:\([0-9][0-9]*\)$/\1/p')
    gh_body=$(printf '%s' "$gh_out" | sed 's/HTTPSTATUS:[0-9][0-9]*$//')
    if [ "$gh_code" = "502" ] || [ "$gh_code" = "503" ] || [ "$gh_code" = "504" ] || [ -z "$gh_code" ]; then
      sleep "$gh_i"
      gh_i=$((gh_i + 1))
      continue
    fi
    if [ "$gh_code" != "200" ]; then
      echo "HTTP $gh_code" >&2
    fi
    printf '%s' "$gh_body"
    return 0
  done
  echo "ghApi 失败（重试 $gh_tries 次）: $gh_path" >&2
  return 1
}

ghRaw() {
  _gh_curl "$1"
}

ghSearchRepos() {
  local gh_q gh_per gh_sort gh_url
  gh_per="${2:-30}"
  gh_sort=''
  if [ "$3" = "--sort-stars" ]; then
    gh_sort='&sort=stars&order=desc'
  fi
  gh_q=$(jq -rn --arg s "$1" '$s|@uri')
  gh_url="/search/repositories?q=${gh_q}&per_page=${gh_per}${gh_sort}"
  ghApi "$gh_url" | jq -r '.items[]? | "\(.stargazers_count)★\t\(.full_name)\t\(.description // "")\t\(.html_url)"'
}

# ---------- 认证 ----------

ghMe() {   # 当前身份 + 速率余量
  ghApi /user | jq -r '"\(.login)\t\(.name // "-")\t私有仓库 \(.total_private_repos // 0)"'
}

ghRate() {
  ghApi /rate_limit | jq -r '"\(.rate.remaining)/\(.rate.limit)  重置 \(.rate.reset|todate)"'
}

_gh_post() {   # $1=url $2=json  → 带认证的 POST
  local gh_tok
  gh_tok=$(_gh_token)
  if [ -z "$gh_tok" ]; then echo "需要 token(写操作)" >&2; return 1; fi
  curl -sS -m 60 -A "$GH_UA" -H "Authorization: Bearer $gh_tok" \
    -H 'Accept: application/vnd.github+json' -X POST -d "$2" "$1"
}

# ---------- Release ----------

# 附件参数支持两种写法：
#   普通路径            → 用文件名当附件名
#   "名字=路径"          → 指定附件名（文件名含中文/空格时**必须**这么写）
# ⚠️ GitHub 对**非 ASCII 附件名**处理有问题：`大肥鱼.app.zip` 传上去会变成 `app.zip`
#    （中文段被吃掉，实测 2026-09-11）。所以附件名一律用 ASCII。
ghReleaseCreate() {   # <owner/repo> <tag> <标题> [说明] [附件...]
  local repo="$1" tag="$2" title="$3" body="${4:-}"
  [ "$#" -ge 4 ] && shift 4
  local json out id
  json=$(jq -n --arg t "$tag" --arg n "$title" --arg b "$body" \
    '{tag_name:$t,name:$n,body:$b,draft:false,prerelease:false}')
  out=$(_gh_post "https://api.github.com/repos/$repo/releases" "$json") || return 1
  id=$(printf '%s' "$out" | jq -r '.id // empty')
  if [ -z "$id" ]; then
    echo "建 Release 失败: $(printf '%s' "$out" | jq -r '.message // .')" >&2
    return 1
  fi
  echo "Release 已建: $(printf '%s' "$out" | jq -r '.html_url')"

  local spec f nm enc r
  for spec in "$@"; do
    case "$spec" in
      *=*) nm="${spec%%=*}"; f="${spec#*=}" ;;
      *)   f="$spec"; nm=$(basename "$f") ;;
    esac
    if [ ! -f "$f" ]; then echo "  跳过(不存在): $f" >&2; continue; fi
    if printf '%s' "$nm" | LC_ALL=C grep -q '[^ -~]'; then
      echo "  ⚠️  附件名含非 ASCII:'$nm' —— GitHub 会把它截断,请用 \"AsciiName=路径\" 指定" >&2
    fi
    enc=$(jq -rn --arg s "$nm" '$s|@uri')
    r=$(curl -sS -m 600 -A "$GH_UA" \
      -H "Authorization: Bearer $(_gh_token)" \
      -H "Content-Type: application/octet-stream" \
      --data-binary "@$f" \
      "https://uploads.github.com/repos/$repo/releases/$id/assets?name=$enc")
    if printf '%s' "$r" | jq -e '.state == "uploaded"' >/dev/null 2>&1; then
      echo "  附件已传: $(printf '%s' "$r" | jq -r '.name') ($(printf '%s' "$r" | jq -r '.size') 字节)"
    else
      echo "  附件失败: $nm → $(printf '%s' "$r" | jq -r '.message // .')" >&2
    fi
  done
}

ghReleases() {   # <owner/repo>
  ghApi "/repos/$1/releases" | jq -r '.[]? | "\(.tag_name)\t\(.name)\t\(.published_at)\t\((.assets|length)) 个附件"'
}

case "${BASH_SOURCE[0]:-$0}" in
  "$0") echo "gh.sh: 请用 source 加载后调用函数"; echo "  source ~/DeepSeekHarness/projects/gh.sh"; echo "  ghSearchRepos dsh-plugin 5 --sort-stars | ghApi /repos/owner/repo | ghRate | ghMe" ;;
esac
