#!/usr/bin/env bash
# cache.sh — 运行缓存目录的建立 / 清理 / 盘点(截图、快照、临时 JSON 只放这里)
#
# 用法:
#   bash cache.sh init                 # 建本次运行目录并打印路径(唯一 stdout 输出),顺手清扫 2 天前的旧目录
#   bash cache.sh clean <目录>          # 删除指定运行目录并回读确认
#   bash cache.sh status               # 只读:列出本机现有缓存目录与大小
#
# 设计:
#   - 目录权限 0700:截图含课程名、姓名、题目,只给当前用户读;
#   - 不写仓库、不写用户目录,只落在系统临时区($TMPDIR 或 /tmp);
#   - 清理不依赖 Agent 记得:init 时自动清掉 2 天前的残留(中途断线/崩溃留下的);
#   - clean 只删自己命名的目录,路径不合规直接拒绝(exit 3),避免 rm -rf 打偏。
#
# 退出码: 0 = 成功 | 1 = 操作失败 | 2 = 用法错误 | 3 = 拒绝清理(路径不合规)
set -u

BASE="${CHAOXING_CACHE_BASE:-${TMPDIR:-/tmp}/chaoxing-watch-cache}"
MAX_AGE_DAYS=2

usage() {
  cat <<'EOF'
用法:
  bash cache.sh init            # 建运行目录,打印路径(供 CACHE_DIR="$(...)" 使用)
  bash cache.sh clean <目录>     # 删除指定运行目录
  bash cache.sh status          # 只读盘点

退出码: 0=成功 1=失败 2=用法错误 3=拒绝清理(路径不合规)
EOF
}

do_init() {
  mkdir -p "$BASE" || { echo "FAIL: 建不了缓存根目录: $BASE" >&2; return 1; }
  chmod 700 "$BASE" 2>/dev/null || true

  # 清掉上次崩溃/断线留下的旧目录(2 天前)
  find "$BASE" -mindepth 1 -maxdepth 1 -type d -mtime "+$MAX_AGE_DAYS" \
    -exec rm -rf {} + 2>/dev/null || true

  local d
  d="$(mktemp -d "$BASE/run.XXXXXXXX")" || { echo "FAIL: mktemp 失败($BASE)" >&2; return 1; }
  chmod 700 "$d" 2>/dev/null || true
  printf '%s\n' "$d"
}

do_clean() {
  local d="${1:-}"
  if [ -z "$d" ]; then
    echo "FAIL: clean 需要一个目录参数(用 init 打印出来的那个)" >&2
    usage >&2
    return 2
  fi

  # 只删自己建的:必须在 $BASE 下、名字以 run. 开头、不是根/家目录
  case "$d" in
    "$BASE"/run.*) : ;;
    *)
      echo "REFUSED: 只清理 $BASE/run.* 形式的目录,不删: $d" >&2
      return 3
      ;;
  esac
  if [ ! -d "$d" ]; then
    echo "OK: 目录已不存在: $d"
    return 0
  fi

  rm -rf -- "$d" || { echo "FAIL: 删除失败: $d" >&2; return 1; }
  if [ -e "$d" ]; then
    echo "FAIL: 删除后目录仍在: $d" >&2
    return 1
  fi
  echo "OK: 缓存已清理: $d"
}

do_status() {
  if [ ! -d "$BASE" ]; then
    echo "无缓存目录($BASE 不存在)。"
    return 0
  fi
  local n=0 d
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    n=$((n + 1))
    printf '%s  %s\n' "$(du -sh "$d" 2>/dev/null | cut -f1)" "$d"
  done < <(find "$BASE" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
  if [ "$n" -eq 0 ]; then
    echo "无缓存目录(根目录为空: $BASE)。"
  else
    echo "共 $n 个($BASE);init 会自动清扫 2 天前的残留。"
  fi
}

case "${1:-}" in
  init)   do_init; exit $? ;;
  clean)  shift; do_clean "${1:-}"; exit $? ;;
  status) do_status; exit $? ;;
  ""|-h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac
