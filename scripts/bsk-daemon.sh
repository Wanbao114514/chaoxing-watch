#!/usr/bin/env bash
# bsk-daemon.sh — skill 的 daemon 生命周期管理(启动 / 停止 / 看状态 / 自检)。
#
# 用法:
#   bash bsk-daemon.sh                # = start,空闲存活 2h
#   bash bsk-daemon.sh start [idle]   # 幂等启动,已在跑直接返回
#   bash bsk-daemon.sh stop           # 任务收尾:关掉 daemon(连 Agent Window 一起收)
#   bash bsk-daemon.sh status         # 只读探测
#   bash bsk-daemon.sh doctor         # 只读自检:依赖 / daemon / 浏览器接入,不启动任何东西
#
# 退出码: 0 = 成功/已就绪/已停止 | 1 = 启动失败 | 3 = 命名管道被沙箱拦截 | 4 = 找不到 bsk(或缺少 nohup)
#         doctor 额外: 0 = 全部通过(可有 WARN) | 1 = 有 FAIL | 3 = 命名管道被拦截
#
# 背景(实测):
#   - bsk 客户端默认会自己"幽灵拉起"daemon(BSK_AUTO_START),但本宿主禁止 Job Object
#     breakaway,自动拉起必然报 "cannot start an independent Windows daemon ... os error 5";
#     所以探测与启动一律带 BSK_AUTO_START=0,由本脚本用 --foreground + nohup 负责。
#   - daemon 必须活到发起它的 shell 之外,否则 ops_bash 结束就被连带回收。
#   - 空闲自杀(--daemon-idle)不可靠:浏览器扩展连着时 daemon 可以几十分钟不退,
#     所以"任务结束就关"必须显式 stop,不能指望计时器。
#   - 排查顺序固定为 doctor → start → 复跑:先看是"没装/没连"还是"被沙箱拦",
#     别一上来就重启 daemon(§7 排障表同此顺序)。

set -u

MODE="${1:-start}"
IDLE="${2:-2h}"
SESSION_IDLE="${SESSION_IDLE:-2h}"
LOG="${TMPDIR:-/tmp}/bsk-daemon-start.log"

find_bsk() {
  if command -v bsk >/dev/null 2>&1; then command -v bsk; return 0; fi
  for p in "/c/Users/$USER/bin/bsk.exe" "$HOME/bin/bsk.exe" \
           "/c/Users/$USER/.cargo/bin/bsk.exe" "$HOME/.cargo/bin/bsk.exe" \
           "$HOME/.local/bin/bsk"; do   # 最后一项是 macOS/Linux install.sh 的默认位置
    [ -x "$p" ] && { echo "$p"; return 0; }
  done
  return 1
}

BSK=""
if ! BSK="$(find_bsk)"; then
  BSK=""
  # doctor 要把其余检查跑完才有诊断价值,所以只在真正要干活时才因缺 bsk 直接退出
  if [ "$MODE" != "doctor" ]; then
    echo "FAIL: 找不到 bsk CLI。把 bsk.exe 放到 ~/.cargo/bin/ 或 ~/bin/,或改 profile 的 bskPath。" >&2
    exit 4
  fi
fi

# 纯读探测:关掉 CLI 自己的自动拉起,避免每次探测都撞出 breakaway 报错
probe() { BSK_AUTO_START=0 "$BSK" status --json 2>&1; }

is_up() { printf '%s' "$1" | grep -q '"daemon_version"'; }

lock_free_log() {
  : >"$LOG" 2>/dev/null || LOG="${TMPDIR:-/tmp}/bsk-daemon-start.$$.log"
}

report() {
  local out="$1" pid browsers
  pid="$(printf '%s' "$out" | sed -n 's/.*"pid": *\([0-9]*\).*/\1/p' | head -1)"
  browsers="$(printf '%s' "$out" | grep -c '"instance_id"')"
  echo "OK: daemon 已在运行 (pid ${pid:-?}, browsers=${browsers}, idle=${IDLE})"
  if [ "$browsers" -eq 0 ]; then
    echo "NOTE: 尚无浏览器接入 —— 需要时用 app_launch 打开 Edge,等 5–10s 再复查。"
  fi
}

do_start() {
  local out
  if ! command -v nohup >/dev/null 2>&1; then
    echo "FAIL: 找不到 nohup —— daemon 无法活到当前 shell 之外,起不来。" >&2
    echo "HINT: Git Bash / macOS 自带 nohup;精简容器需装 coreutils。" >&2
    return 4
  fi

  out="$(probe)"
  if is_up "$out"; then report "$out"; return 0; fi

  echo "daemon 未运行,启动中 (idle=${IDLE}) ..."
  lock_free_log
  BSK_AUTO_START=0 nohup "$BSK" daemon start --foreground \
    --daemon-idle "$IDLE" --session-idle "$SESSION_IDLE" >"$LOG" 2>&1 &
  disown 2>/dev/null || true

  for _ in $(seq 1 40); do
    sleep 0.5
    out="$(probe)"
    if is_up "$out"; then report "$out"; return 0; fi
  done

  if grep -qiE '拒绝访问|Access is denied|os error 5' "$LOG" 2>/dev/null; then
    echo "FAIL: 命名管道/IPC 被拦截(拒绝访问)。daemon 起不来或 DSH 接不上。" >&2
    echo "HINT: 用 danger-full-access 文件策略,或把 bsk 的 IPC 端点加进沙箱白名单。" >&2
    return 3
  fi
  echo "FAIL: 20s 内没起来。日志尾部:" >&2
  tail -5 "$LOG" >&2 2>/dev/null
  return 1
}

do_stop() {
  local out sess
  out="$(probe)"
  if ! is_up "$out"; then
    echo "OK: daemon 本就没在跑,无需停止。"
    return 0
  fi

  sess="$("$BSK" session list --json 2>/dev/null | tr -d '[:space:]')"
  if [ -n "$sess" ] && [ "$sess" != "[]" ]; then
    echo "NOTE: 仍有活动 Agent Window 会话,将随 daemon 一起关闭。"
  fi

  "$BSK" daemon stop >/dev/null 2>&1
  for _ in $(seq 1 20); do
    sleep 0.5
    out="$(probe)"
    if ! is_up "$out"; then
      echo "OK: daemon 已停止,Agent Window 与浏览器会话已释放。"
      return 0
    fi
  done

  echo "FAIL: 10s 内没停下来,可能被其它进程占用:" >&2
  "$BSK" status 2>&1 | head -3 >&2
  return 1
}

# ---- doctor：只读自检，不启动、不修改任何东西 ------------------------------
do_doctor() {
  local ok=0 warn=0 fail=0 pipe_blocked=0 out pid browsers ver

  ok_()   { printf '[OK]   %s\n' "$*"; ok=$((ok + 1)); }
  warn_() { printf '[WARN] %s\n' "$*"; warn=$((warn + 1)); }
  fail_() { printf '[FAIL] %s\n' "$*"; fail=$((fail + 1)); }

  ok_ "OS: $(uname -s 2>/dev/null || echo unknown) $(uname -m 2>/dev/null || true)"
  ok_ "bash: ${BASH_VERSION:-unknown}"

  if command -v nohup >/dev/null 2>&1; then
    ok_ "nohup: $(command -v nohup)"
  else
    fail_ "nohup: 缺失 —— 脚本无法让 daemon 脱离当前 shell 存活"
  fi

  if [ -z "$BSK" ]; then
    fail_ "bsk CLI: 未找到（PATH / ~/.cargo/bin / ~/bin 都没有）"
  else
    ver="$("$BSK" --version 2>/dev/null | head -1)"
    if [ -n "$ver" ]; then
      ok_ "bsk CLI: $BSK ($ver)"
    else
      warn_ "bsk CLI: $BSK 已找到,但 --version 没输出"
    fi
  fi

  if [ -n "$BSK" ]; then
    out="$(probe)"
    if is_up "$out"; then
      pid="$(printf '%s' "$out" | sed -n 's/.*"pid": *\([0-9]*\).*/\1/p' | head -1)"
      ok_ "daemon: 运行中 (pid ${pid:-?})"
      browsers="$(printf '%s' "$out" | grep -c '"instance_id"')"
      if [ "$browsers" -eq 0 ]; then
        warn_ "浏览器: 尚未接入 —— 用 app_launch 打开 Edge/Chrome,等 5–10s 再复查"
      else
        ok_ "浏览器: ${browsers} 个实例已接入"
      fi
    elif printf '%s' "$out" | grep -qiE '拒绝访问|Access is denied|os error 5'; then
      fail_ "daemon: 命名管道 \\.\\pipe\\bsk-daemon-* 被拦截（os error 5）"
      echo "       → 文件策略需 danger-full-access，或把 bsk 的 IPC 端点加进白名单"
      pipe_blocked=1
    else
      warn_ "daemon: 未运行（doctor 不会启动它；需要时跑 bash bsk-daemon.sh）"
    fi
  fi

  printf '检查完成：%d 项通过，%d 项警告，%d 项失败\n' "$ok" "$warn" "$fail"
  if [ "$pipe_blocked" -eq 1 ]; then return 3; fi
  if [ "$fail" -gt 0 ]; then return 1; fi
  return 0
}

case "$MODE" in
  start|"") do_start; exit $? ;;
  stop)     do_stop;  exit $? ;;
  status)
    out="$(probe)"
    if is_up "$out"; then report "$out"; exit 0; fi
    echo "daemon 未运行。"; exit 1 ;;
  doctor)   do_doctor; exit $? ;;
  *)  echo "用法: bash bsk-daemon.sh [start [idle] | stop | status | doctor]" >&2; exit 2 ;;
esac
