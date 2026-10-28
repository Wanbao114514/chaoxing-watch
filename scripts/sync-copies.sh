#!/usr/bin/env bash
# sync-copies.sh — 把 chaoxing-watch 同步到所有副本，保证三处一致
#
# 用法:
#   bash sync-copies.sh                     # 同步（默认以 DSH 副本为源）
#   bash sync-copies.sh <源目录>             # 指定源目录（旧写法，仍然支持）
#   bash sync-copies.sh --source <源目录>    # 同上，显式写法
#   bash sync-copies.sh status              # 只比对，不写文件
#   bash sync-copies.sh diff                # 只比对，逐文件列出差异
#   bash sync-copies.sh --dry-run           # 同步的预演：只打印将要做什么
#   bash sync-copies.sh --no-backup         # 覆盖前不备份（默认会备份）
#
# 环境变量:
#   DESKTOP_REPO     桌面仓库副本路径（默认 ~/Desktop/chaoxing-watch）
#   SYNC_TARGETS     覆盖目标列表，用 ":" 或换行分隔（主要给测试用）
#   SYNC_BACKUP_ROOT 备份根目录（默认 ~/.chaoxing-watch-sync-backup）
#
# 同步内容: SKILL.md + scripts/ 下所有脚本(README/LICENSE/.gitignore 只在仓库;sync-copies.sh 自身不同步)
#
# 行为约定（针对「改了仓库又被旧副本覆盖」这个坑）:
#   1. 逐文件先比对内容，相同就 skip —— 不做无意义的覆盖（旧版是无条件 cp -f）;
#   2. 真要覆盖前，先把目标文件备份到 $SYNC_BACKUP_ROOT/<时间戳>/ 下;
#   3. status / diff / --dry-run 全程只读，不建目录、不备份、不写文件;
#   4. 目标目录/文件不存在时才会新建，并在输出里标 [add]，便于事后核对。
#
# 退出码: 0 = 一致或已同步 | 1 = 有失败 | 2 = 用法错误 | 3 = 只读模式下发现差异
set -euo pipefail

# 文件清单:SKILL.md + scripts/ 下除本脚本外的所有文件(自动发现,加新脚本不用改这里)
FILES=(SKILL.md)

MODE=sync          # sync | status | diff | preview
SRC=""
BACKUP=1

usage() {
  cat <<'EOF'
用法: bash sync-copies.sh [选项] [源目录]
      bash sync-copies.sh status | diff

  <源目录>            以该目录为源（默认 ~/.dsh/skills/chaoxing-watch）
  --source <源目录>   同上，显式写法
  --dry-run           只预演，不写任何文件
  --no-backup         覆盖前不备份
  -h, --help          显示本帮助

退出码: 0=一致/已同步  1=有失败  2=用法错误  3=只读模式发现差异
EOF
}

die_usage() { echo "FAIL: $1" >&2; usage >&2; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    status|diff) MODE="$1"; shift ;;
    --dry-run)   MODE=preview; shift ;;
    --no-backup) BACKUP=0; shift ;;
    --source)
      if [ $# -lt 2 ] || [ -z "${2:-}" ]; then die_usage "--source 需要一个目录参数"; fi
      SRC="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --*) die_usage "未知选项: $1" ;;
    *)
      if [ -n "$SRC" ]; then die_usage "多余的参数: $1（源目录只能给一个）"; fi
      SRC="$1"; shift ;;
  esac
done

SRC="${SRC:-$HOME/.dsh/skills/chaoxing-watch}"
DESKTOP_REPO="${DESKTOP_REPO:-$HOME/Desktop/chaoxing-watch}"

# 目标列表：默认三处；SYNC_TARGETS 可覆盖（测试用）
if [ -n "${SYNC_TARGETS:-}" ]; then
  IFS=':' read -r -a TARGETS <<< "$(printf '%s' "$SYNC_TARGETS" | tr '\n' ':')"
else
  TARGETS=(
    "$HOME/.dsh/skills/chaoxing-watch"
    "$HOME/.agents/skills/chaoxing-watch"
    "$DESKTOP_REPO"
  )
fi

[ -f "$SRC/SKILL.md" ] || { echo "FAIL: 源目录里没有 SKILL.md: $SRC" >&2; exit 1; }
SRC_ABS="$(cd "$SRC" && pwd)"

# scripts/ 自动纳入(本脚本自身不同步):以后加脚本不用再改清单,避免漏同步
if [ -d "$SRC/scripts" ]; then
  for f in "$SRC"/scripts/*; do
    [ -f "$f" ] || continue
    b="$(basename "$f")"
    [ "$b" = "sync-copies.sh" ] && continue
    FILES+=("scripts/$b")
  done
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_ROOT="${SYNC_BACKUP_ROOT:-$HOME/.chaoxing-watch-sync-backup}/$STAMP"
want_write=0
if [ "$MODE" = "sync" ]; then want_write=1; fi

for rel in "${FILES[@]}"; do
  if [ ! -f "$SRC/$rel" ]; then
    echo "WARN: 源里缺 $rel，这个文件会被跳过（不影响其它文件）" >&2
  fi
done

same=0 updated=0 created=0 failed=0 drifted=0

backup_one() { # $1=相对路径，$2=目标目录
  local rel="$1" t="$2" slug
  slug="$(printf '%s' "$t" | sed 's|^/||; s|/|_|g')"
  mkdir -p "$BACKUP_ROOT/$slug/$(dirname "$rel")"
  cp -f "$t/$rel" "$BACKUP_ROOT/$slug/$rel"
}

for t in "${TARGETS[@]}"; do
  # 跳过源自身
  if [ -d "$t" ] && [ "$(cd "$t" && pwd)" = "$SRC_ABS" ]; then
    echo "skip  (source)  $t"
    continue
  fi

  t_same=0 t_diff=0
  for rel in "${FILES[@]}"; do
    if [ ! -f "$SRC/$rel" ]; then continue; fi

    if [ ! -f "$t/$rel" ]; then
      a=add
    elif cmp -s "$SRC/$rel" "$t/$rel"; then
      a=same
    else
      a=update
    fi

    if [ "$a" = "same" ]; then
      t_same=$((t_same + 1))
      if [ "$MODE" = "diff" ]; then echo "  [same]   $rel"; fi
      continue
    fi

    # 有差异（新增或更新）
    t_diff=$((t_diff + 1))
    if [ "$MODE" = "diff" ] || [ "$MODE" = "preview" ]; then
      echo "  [$a]     $rel"
      if [ "$a" = "update" ] && [ "$MODE" = "diff" ]; then
        diff -u "$t/$rel" "$SRC/$rel" 2>/dev/null | sed -n '1,20p' | sed 's/^/           /' || true
      fi
    fi

    if [ "$want_write" -eq 1 ]; then
      if [ "$a" = "update" ] && [ "$BACKUP" -eq 1 ]; then backup_one "$rel" "$t"; fi
      mkdir -p "$t/$(dirname "$rel")"
      cp -f "$SRC/$rel" "$t/$rel"
      if cmp -s "$SRC/$rel" "$t/$rel"; then
        if [ "$a" = "add" ]; then created=$((created + 1)); else updated=$((updated + 1)); fi
      else
        echo "FAIL: 复制后校验不一致: $t/$rel" >&2
        failed=$((failed + 1))
      fi
    fi
  done

  if [ "$MODE" = "sync" ]; then
    if [ "$t_diff" -eq 0 ]; then
      echo "OK       $t  （$t_same 个文件均一致，未改动）"
    else
      echo "OK       $t  （更新 $t_diff 个，一致 $t_same 个）"
    fi
  else
    if [ "$t_diff" -eq 0 ]; then
      echo "OK       $t  （全部一致）"
    else
      echo "DRIFT    $t  （$t_diff 个文件不同）"
      drifted=$((drifted + 1))
    fi
  fi
done

case "$MODE" in
  sync)
    if [ "$failed" -gt 0 ]; then
      echo "done: 有 $failed 处失败" >&2
      exit 1
    fi
    if [ "$updated" -eq 0 ] && [ "$created" -eq 0 ]; then
      echo "done: 全部副本早已一致，未改动任何文件"
    else
      echo "done: 新建 $created 个、更新 $updated 个文件"
      if [ "$BACKUP" -eq 1 ] && [ "$updated" -gt 0 ]; then
        echo "备份: $BACKUP_ROOT"
      fi
    fi
    ;;
  *)
    if [ "$drifted" -gt 0 ]; then
      echo "done: $drifted 个副本有差异（只读模式，未修改任何文件）"
      exit 3
    fi
    echo "done: 所有副本一致"
    ;;
esac
