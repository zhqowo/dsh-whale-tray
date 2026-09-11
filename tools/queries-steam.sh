#!/bin/bash
# steam.sh -- Steam 查询工具 (macOS/Linux 版, 对齐 Windows 的 steam.ps1)
# 用法: source ~/DeepSeekHarness/projects/steam.sh  然后调用 steam-search 等
# key: $STEAM_API_KEY 或 ~/.dsh/steam_api_key.txt
# 注：兼容 bash / zsh（不依赖 word splitting）

STEAM_KEY_FILE="$HOME/.dsh/steam_api_key.txt"
STEAM_UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/120.0 Safari/537.36'

_steam_key() {
  if [ -n "$STEAM_API_KEY" ]; then printf '%s' "$STEAM_API_KEY"; return 0; fi
  if [ -f "$STEAM_KEY_FILE" ]; then tr -d '\r\n' < "$STEAM_KEY_FILE"; return 0; fi
  echo "缺少 Steam key（设 STEAM_API_KEY 或写 ~/.dsh/steam_api_key.txt）" >&2
  return 1
}

_uri() { jq -rn --arg s "$1" '$s|@uri'; }

# 商店接口(免 key)专用:国内链路到 store.steampowered.com 经常第一次就超时
# (实测同一个请求 19s 超时、重试后 0.4s 就回来了),所以必须重试。
_steam_store() {   # $1=url $2=语言 [重试次数]
  local url="$1" lang="${2:-schinese}" tries="${3:-4}"
  local i=1 out
  while [ "$i" -le "$tries" ]; do
    if out=$(curl -sS -m 30 -A "$STEAM_UA" -H "Accept-Language: $lang" "$url"); then
      printf '%s' "$out"
      return 0
    fi
    sleep "$i"
    i=$((i + 1))
  done
  echo "Steam 商店接口请求失败(试了 $tries 次): $url" >&2
  return 1
}

_steam_api() {   # $1=url(不含 key) [重试次数]
  local url="$1"
  local tries="${2:-4}"
  local i=1 sep out key
  key=$(_steam_key) || return 1
  case "$url" in
    *\?*) sep='&' ;;
    *)    sep='?' ;;
  esac
  while [ "$i" -le "$tries" ]; do
    if out=$(curl -sS -m 30 -A "$STEAM_UA" "${url}${sep}key=${key}"); then
      printf '%s' "$out"
      return 0
    fi
    sleep "$i"
    i=$((i + 1))
  done
  echo "Steam API 请求失败: $url" >&2
  return 1
}

# ---------- 商店（免 key） ----------
steam-search() {   # <关键词> [cc] [语言]
  local term="$1"
  local cc="${2:-cn}"
  local l="${3:-schinese}"
  _steam_store \
    "https://store.steampowered.com/api/storesearch?term=$(_uri "$term")&cc=$cc&l=$l" "$l" \
  | jq -r '.items[]? | "\(.id)\t\(.name)\t\(if .price then (.price.final/100|tostring) + " " + .price.currency else "免费/无价" end)"'
}

steam-appdetails() {   # <appid> [语言] [cc]
  local l="${2:-schinese}"
  _steam_store \
    "https://store.steampowered.com/api/appdetails?appids=$1&l=$l&cc=${3:-cn}" "$l" | jq .
}

# ---------- Web API（需 key） ----------
steam-playersummary() {   # <steamid64>
  _steam_api "https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/?steamids=$1" \
  | jq -r '.response.players[]? | "\(.steamid)\t\(.personaname)\t\(.personastate)\t\(.loccountrycode // "-")"'
}

steam-ownedgames() {   # <steamid64> 游戏数+总时长+Top15
  local json
  json=$(_steam_api "https://api.steampowered.com/IPlayerService/GetOwnedGames/v1/?steamid=$1&include_appinfo=1&include_played_free_games=1") || return 1
  printf '%s' "$json" | jq -r '"游戏数: \(.response.game_count)   总时长: \((.response.games|map(.playtime_forever)|add)/60|floor) 小时"'
  printf '%s' "$json" | jq -r '.response.games | sort_by(-.playtime_forever)[:15][] | "\(.playtime_forever/60|floor)h\t\(.name)\t(\(.appid))"'
}

steam-playercount() {   # <appid>
  _steam_api "https://api.steampowered.com/ISteamUserStats/GetNumberOfCurrentPlayers/v1/?appid=$1" \
  | jq -r '"当前在线: \(.response.player_count)"'
}

steam-achievementpct() {   # <appid>
  _steam_api "https://api.steampowered.com/ISteamUserStats/GetGlobalAchievementPercentagesForApp/v2/?gameid=$1" \
  | jq -r '.achievementpercentages.achievements[]? | "\(.percent|.*100|round/100)%\t\(.name)"'
}

steam-news() {   # <appid> [条数]
  _steam_api "https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=$1&count=${2:-5}" \
  | jq -r '.appnews.newsitems[]? | "\(.title)\n  \(.url)\n"'
}

steam-schema() {   # <appid>
  _steam_api "https://api.steampowered.com/ISteamUserStats/GetSchemaForGame/v2/?appid=$1" | jq .
}

steam-playerachievements() {   # <appid> <steamid64>
  _steam_api "https://api.steampowered.com/ISteamUserStats/GetPlayerAchievements/v1/?appid=$1&steamid=$2" | jq .
}

steam-resolvevanity() {   # <自定义ID>
  _steam_api "https://api.steampowered.com/ISteamUser/ResolveVanityURL/v1/?vanityurl=$1" | jq .
}

steam-leaderboards() {   # <appid>
  _steam_api "https://api.steampowered.com/ISteamLeaderboards/GetLeaderboardsForGame/v2/?appid=$1" | jq .
}

steam-workshop() {   # <appid> [搜索词] [页] [每页]
  local extra=''
  if [ -n "$2" ]; then extra="&search_text=$(_uri "$2")"; fi
  _steam_api "https://api.steampowered.com/IPublishedFileService/QueryFiles/v1/?query_type=3&page=${3:-1}&appid=$1&numperpage=${4:-10}${extra}" \
  | jq -r '.response.publishedfiledetails[]? | "\(.publishedfileid)\t\(.title)"'
}

steam-workshopitem() {   # <publishedfileid>
  local key
  key=$(_steam_key) || return 1
  curl -sS -m 30 -A "$STEAM_UA" -X POST \
    -d "itemcount=1" -d "publishedfileids[0]=$1" -d "key=${key}" \
    "https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/" | jq .
}

# ---------- 好友 ----------
steam-friendlist() {   # <steamid64>  输出每行一个 steamid
  _steam_api "https://api.steampowered.com/ISteamUser/GetFriendList/v1/?steamid=$1&relationship=friend" \
  | jq -r '.friendslist.friends[]?.steamid'
}

steam-friends() {   # <steamid64> 好友+状态
  local ids joined
  ids=$(steam-friendlist "$1") || return 1
  if [ -z "$ids" ]; then echo "（无好友数据：资料未公开或无好友）"; return 0; fi
  joined=$(printf '%s\n' "$ids" | paste -sd, -)
  _steam_api "https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/?steamids=$joined" \
  | jq -r '.response.players[]? | "\(.steamid)\t\(.personaname)\t\(.personastate)\t\(.gameextrainfo // "-")"'
}

steam-friend-recent() {   # <好友steamid64> [条数]
  _steam_api "https://api.steampowered.com/IPlayerService/GetRecentlyPlayedGames/v1/?steamid=$1&count=${2:-5}" | jq .
}

steam-friends-recent() {   # <steamid64> 批量查好友最近游玩
  local ids
  ids=$(steam-friendlist "$1") || return 1
  if [ -z "$ids" ]; then echo "（无好友数据）"; return 0; fi
  printf '%s\n' "$ids" | while IFS= read -r id; do
    [ -z "$id" ] && continue
    _steam_api "https://api.steampowered.com/IPlayerService/GetRecentlyPlayedGames/v1/?steamid=${id}&count=5" 2>/dev/null \
    | jq -r --arg id "$id" '.response as $r | if ($r.total_count // 0) > 0 then "\($id)  最近: " + ($r.games|map(.name)|join(", ")) else empty end'
  done
}

case "${BASH_SOURCE[0]:-$0}" in
  "$0") echo "steam.sh: 请用 source 加载后调用函数"; echo "  source ~/DeepSeekHarness/projects/steam.sh"; echo "  steam-search 艾尔登法环 | steam-ownedgames 76561198809739186 | steam-playercount 1245620" ;;
esac
