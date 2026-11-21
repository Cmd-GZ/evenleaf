#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 从 GitHub Release 取回各卷成品 PDF，放回 books/<卷>/ 下原有的位置。
#
# 用法：  scripts/fetch-pdfs.sh            # 检查并下载
#         scripts/fetch-pdfs.sh --check    # 只看状态，不下载
#         scripts/fetch-pdfs.sh --force    # 跳过版本核对，直接下载最新
#         scripts/fetch-pdfs.sh --wait 300 # 若有构建在跑，最多等 300 秒
#
# 判定方式（两条并用）：
#   1. 版本闸：Release 的标签形如 build-YYYY-MM-DD-<sha>；把 <sha> 与本地
#      「最近一次动过构建输入」的提交（books/ shared/ texmf/ 与工作流）比对，
#      不一致说明远端还没编到这一版，不下。
#   2. 状态提示：查该提交对应的 Actions 运行，报告 queued / in_progress /
#      success / failure，便于判断是「还没轮到」还是「编挂了」。
#      状态只作提示，不单独作为下载依据——运行成功也可能对应旧提交。
#
# 公开仓库不需要 token；设 GITHUB_TOKEN 可提高 API 速率上限。
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CHECK_ONLY=0
FORCE=0
WAIT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --check) CHECK_ONLY=1; shift ;;
    --force) FORCE=1; shift ;;
    --wait)  WAIT="${2:?--wait 需要一个秒数}"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "未知参数：$1" >&2; exit 2 ;;
  esac
done

# ---- 仓库地址 --------------------------------------------------------------
url=$(git config --get remote.origin.url 2>/dev/null || true)
case "$url" in
  git@github.com:*)        REPO=${url#git@github.com:} ;;
  https://github.com/*)    REPO=${url#https://github.com/} ;;
  *) REPO="${REPO:-Cmd-GZ/thunder-of-war}" ;;
esac
REPO=${REPO%.git}

api() {
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" "$1"
  else
    curl -fsSL -H "Accept: application/vnd.github+json" "$1"
  fi
}

# ---- 本地应当对应的提交 ----------------------------------------------------
want_full=$(git log -1 --format=%H -- books shared texmf .github/workflows 2>/dev/null || true)
want=${want_full:0:7}
[ -n "$want" ] || { echo "错误：取不到 books/ 的最近提交，确认在仓库根目录运行。" >&2; exit 1; }

# ---- 远端 Release ----------------------------------------------------------
rel=$(api "https://api.github.com/repos/$REPO/releases/latest") || {
  echo "错误：取不到 $REPO 的最新 Release（仓库是否公开、是否已发布过？）" >&2; exit 2; }

TAG=$(printf '%s' "$rel" | python3 -c 'import json,sys;print(json.load(sys.stdin)["tag_name"])')
REL_SHA=${TAG##*-}
ASSETS=$(printf '%s' "$rel" | python3 -c 'import json,sys;print(" ".join(a["name"] for a in json.load(sys.stdin)["assets"]))')

echo "远端最新 Release：$TAG"
echo "  Release 对应提交：$REL_SHA"
echo "  本地构建输入最新提交：$want"

# ---- Actions 运行状态（仅提示） --------------------------------------------
run_of() {
  api "https://api.github.com/repos/$REPO/actions/runs?head_sha=$1&per_page=1" \
    | python3 -c 'import json,sys; r=json.load(sys.stdin)["workflow_runs"]; print("%s %s" % (r[0]["status"], r[0]["conclusion"] or "-") if r else "none -")' 2>/dev/null || echo "unknown -"
}

status=$(run_of "$want_full")
echo "  该提交的构建状态：${status%% *} ${status##* }"

if [ "$WAIT" -gt 0 ]; then
  waited=0
  while :; do
    st=${status%% *}
    [ "$st" = "queued" ] || [ "$st" = "in_progress" ] || break
    [ "$waited" -ge "$WAIT" ] && { echo "等待超时（${WAIT}s），继续按当前状态判断。"; break; }
    sleep 10; waited=$((waited+10))
    status=$(run_of "$want_full")
  done
  [ "$WAIT" -gt 0 ] && echo "  等待后状态：${status%% *} ${status##* }"
fi

# ---- 版本闸 ----------------------------------------------------------------
if [ "$FORCE" -eq 0 ] && [ "$REL_SHA" != "$want" ]; then
  echo
  echo "未下载：远端 Release 还停在 $REL_SHA，本地构建输入已到 $want。"
  case "${status%% *}" in
    queued|in_progress) echo "构建正在跑，等它完成后再执行本脚本（或加 --wait）。" ;;
    completed)
      if [ "${status##* }" = "success" ]; then
        echo "构建已完成但 Release 尚未更新，稍等片刻重试。"
      else
        echo "该提交的构建失败，见 Actions 日志；修正后重新推送。"
      fi ;;
    *) echo "该提交似乎还没有构建记录。" ;;
  esac
  exit 3
fi

[ "$CHECK_ONLY" -eq 1 ] && { echo; echo "版本一致，可以下载（--check 模式，未下载）。"; exit 0; }

# ---- 下载 ------------------------------------------------------------------
echo
fail=0
for dir in books/*/; do
  [ -f "$dir/build.sh" ] || continue
  name=$(basename "$dir")
  dist=$(sed -n 's/^DIST="\(.*\)"$/\1/p' "$dir/build.sh" | head -1)
  [ -n "$dist" ] || { echo "跳过 $name：build.sh 里没有 DIST= 定义" >&2; continue; }
  case " $ASSETS " in
    *" $name.pdf "*) ;;
    *) echo "跳过 $name：Release 里没有 $name.pdf" >&2; continue ;;
  esac
  echo -n "  $name → $dir$dist ... "
  if curl -fsSL -o "$dir$dist" \
      "https://github.com/$REPO/releases/download/$TAG/$name.pdf"; then
    echo "完成"
  else
    echo "失败"; fail=1
  fi
done

if [ "$fail" -eq 0 ]; then
  echo
  echo "全部下载完毕。"
else
  echo
  echo "有文件下载失败，见上。" >&2
  exit 1
fi
