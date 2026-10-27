#!/usr/bin/env bash
# sync-copies.sh — 把 chaoxing-watch 同步到所有副本，保证三处一致
#
# 用法:
#   bash sync-copies.sh                 # 默认以 DSH 副本为源
#   bash sync-copies.sh <源目录>         # 指定源目录
#   DESKTOP_REPO=~/Desktop/chaoxing-watch bash sync-copies.sh
#
# 同步内容: SKILL.md + scripts/ 下两个脚本（README/LICENSE 只在仓库里）
# 退出码: 0 = 全部同步成功且校验一致 | 1 = 有副本失败
set -euo pipefail

SRC="${1:-$HOME/.dsh/skills/chaoxing-watch}"
DESKTOP_REPO="${DESKTOP_REPO:-$HOME/Desktop/chaoxing-watch}"

TARGETS=(
  "$HOME/.dsh/skills/chaoxing-watch"
  "$HOME/.agents/skills/chaoxing-watch"
  "$DESKTOP_REPO"
)

[ -f "$SRC/SKILL.md" ] || { echo "FAIL: 源目录里没有 SKILL.md: $SRC" >&2; exit 1; }
SRC_ABS="$(cd "$SRC" && pwd)"

fail=0
for t in "${TARGETS[@]}"; do
  # 跳过源自身
  if [ -d "$t" ] && [ "$(cd "$t" && pwd)" = "$SRC_ABS" ]; then
    echo "skip  (source)  $t"
    continue
  fi
  mkdir -p "$t/scripts"
  cp -f "$SRC/SKILL.md" "$t/SKILL.md" || { echo "FAIL copy $t" >&2; fail=1; continue; }
  for f in bsk-daemon.sh win-minimize.ps1; do
    [ -f "$SRC/scripts/$f" ] && cp -f "$SRC/scripts/$f" "$t/scripts/$f"
  done
  if diff -q "$SRC/SKILL.md" "$t/SKILL.md" >/dev/null 2>&1; then
    echo "OK     $t"
  else
    echo "MISMATCH $t" >&2
    fail=1
  fi
done

[ "$fail" -eq 0 ] && echo "done: 所有副本一致" || { echo "done: 有副本失败" >&2; exit 1; }
