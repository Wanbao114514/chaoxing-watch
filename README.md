# chaoxing-watch

在学习通（超星）网页版按章节刷课的小技能：**课程模块**用 2 倍速 + 静音把视频放到后台播完，**答题模块**处理章节测验（单选 / 多选 / 判断 / 填空 / 简答），读题只靠截图、答案由模型自己给、提交前先问用户。

全程只通过 [BrowserSkill](https://github.com/Tencent/BrowserSkill)（`bsk` CLI + 浏览器扩展）操作，不碰桌面坐标、不模拟键鼠。

## 功能

| 模块 | 做什么 | 完成判据 |
| --- | --- | --- |
| 课程模块 | 截图认课 → 目录挑未完成的节 → 2 倍速 + 静音 → 最小化后台播 | 页面出现 `任务点已完成` |
| 答题模块 | 进章节测验 → 截图读题 → 点选/填空 → 提交前询问 | 弹窗消失 + 标题 `已完成` |

两个模块互不调用，一次只跑一个。

## 为什么推荐 DSH（而不是 Codex）

两套跑法都支持：DSH 走 `bsk_*` 工具，Codex 等 CLI 走 `bsk` 子命令；Windows 和 macOS 两端都能用。**但日常推荐 DSH**：

- 窗口最小化 / 还原、截图、播放器与任务点状态回读都有原生工具（`computer_*` + `bsk_*`），不用自己拼 `bsk` 命令、按页面标题匹配窗口；
- 起播后最小化、答题前还原这类窗口动作是现成的，CLI 下还得依赖 `win-minimize.ps1`（Windows）或 `osascript`（macOS），步骤更多、更容易漏；
- 成本可控：一节课（视频 + 章节测验）用 **v4.1 flash low** 刷下来，**谷价时段（DeepSeek 错峰计价）不超过 0.2 元**。

## 依赖

运行本 skill **不需要安装任何 npm 包**，只有两个脚本（bash + PowerShell）。真正要装的是下面这些：

| # | 依赖 | 说明 | 必需 |
| --- | --- | --- | --- |
| 1 | Windows 10/11 或 macOS 13+ | Windows 需要 Git Bash（跑 shell 脚本） | 是 |
| 2 | Microsoft Edge 或 Google Chrome | 必须是 Chromium 内核；Firefox / Safari 不支持 | 是 |
| 3 | BrowserSkill 浏览器扩展 | Edge 从 Edge Add-ons、Chrome 从 Chrome Web Store 装，同一套；图标显示 Connected 才算装好 | 是 |
| 4 | `bsk` CLI | 实测 0.3.3（协议 1.3）；`bsk status` 能连通即正常 | 是 |
| 5 | `bsk` daemon | 由 `scripts/bsk-daemon.sh` 一键起停（幂等） | 是 |
| 6 | PowerShell 5.1+ | 仅 Windows 的窗口最小化脚本 `win-minimize.ps1` 需要 | Windows |
| 7a | DeepSeek Harness + browser-skill 插件 | 走 `bsk_*` 工具那条路 | 二选一 |
| 7b | Codex CLI（实测 0.164.0）或任意能跑 shell 的 agent | 走 `bsk` 子命令那条路 | 二选一 |
| 8 | 学习通账号（已登录、已选课） | 本 skill 不处理登录，未登录直接报错停止 | 是 |

**环境要求**

- Windows：DSH 文件策略需 `danger-full-access`（`workspace-write` 会拦 `\\.\pipe\bsk-daemon-*`，报 `os error 5`）；
- macOS：用 `osascript` 控制窗口，需要在「系统设置 → 隐私与安全性 → 辅助功能」给运行 agent 的终端授权；
- 网络：能访问 `i.chaoxing.com`、`mooc1.chaoxing.com`、`mooc2-ans.chaoxing.com`。

## 安装

### A. DeepSeek Harness（推荐，有 `bsk_*` 工具）

1. 装好 `bsk` CLI 和浏览器扩展（见上表）；
2. 把本目录复制到 `~/.dsh/skills/chaoxing-watch`；
3. 重开会话，技能列表里能看到 `chaoxing-watch` 即可。

### B. 任意 CLI（Codex 等）

```bash
npm i -g @openai/codex
mkdir -p ~/.agents/skills && cp -r chaoxing-watch ~/.agents/skills/
```

运行时必须放开沙箱（否则命名管道被拦）：

```bash
codex exec -s danger-full-access --skip-git-repo-check "看学习通《XX》第 1.1 节"
```

## 怎么下指令（提示词写法）

一条指令按三段写：**① 先叫 skill → ② 说哪门课、哪几节 → ③ 说测验交不交**。三段给全，基本不用反问。

```text
/chaoxing-watch 看《高等数学A(1)》3.2 节
/chaoxing-watch 刷《大学英语（一）》3.2、3.3 两节，章节测验直接提交
/chaoxing-watch 把《线性代数》4.1 的章节测验做了，答案先给我看
```

- **① 叫 skill**：`/chaoxing-watch`，或直接说“用 chaoxing-watch 技能看…”；
- **② 课和节**：课程名可以简写（“高数”→“高等数学A(1)”），节号/标题给一个或多个；没给就从上往下找第一个未完成的节；
- **③ 测验**：写“直接提交”就交，写“先给我看”就停下来等确认；**不写**时交互场景会问一句，Codex 等非交互场景默认只填不交。

其他约定：

- 视频（课程模块）和测验（答题模块）是两条独立流程，要一起做就说“视频刷完顺便把测验做了”；
- 多节默认**做完一节停住**，要连着做请说“连着做，别停”；
- 一次只跑一个模块：视频还在播时别让它同时答题。

## 运行时注意

- 启动后会看到**两个浏览器窗口**：普通窗口 + Agent Window（真正在操作的那个）。普通窗口可以关（见 SKILL.md §0.2.1），但**别关 Agent Window**；
- **刷课期间不要点、切、关正在播放的那个页面**：点它、切标签、关窗都可能让学习通判定“不可见”而暂停，进度甚至回 0:00；
- **别让电脑睡眠**：休眠会把浏览器和 daemon 一起挂起。长课开跑前先关睡眠（Windows `powercfg /change standby-timeout-ac 0`；macOS `caffeinate -dimsu &`）。

## 目录结构

```text
chaoxing-watch/
├── SKILL.md                  # 技能本体（流程、判据、禁令）
├── README.md
├── LICENSE
├── .gitignore
└── scripts/
    ├── bsk-daemon.sh         # daemon 启动 / 停止 / 状态（幂等）
    ├── win-minimize.ps1      # 按窗口标题最小化/还原（给没有 computer_* 的 CLI 用）
    └── sync-copies.sh        # 把本 skill 同步到各处副本
```

## 已知限制

- 只处理**视频**任务点与**章节测验**；阅读、文档、PPT、讨论、作业、考试不处理，遇到会报“跳过”；
- 页面题干被私有字体混淆，只能靠截图读，无法从 DOM 取文本；
- 窗口最小化后无法截图，只能读 `bsk.evaluate` 状态；
- 超星改版可能让选择器/文案失效，需按 SKILL.md §7 排障；
- 答案由模型生成，正确率不保证。

## 合规与免责

- 本项目仅用于**个人学习辅助**，使用者需自行遵守所在学校规定与学习通平台服务条款；
- 不提供账号、不代登录、不绕过验证码；
- 答案由模型生成，可能出错，作者不对成绩或使用后果负责。

## 维护：三份副本

本 skill 通常同时存在于三处：

1. `~/.dsh/skills/chaoxing-watch`（DSH 工作副本）
2. `~/.agents/skills/chaoxing-watch`（Codex 副本）
3. 本仓库（桌面开源副本）

改完 `SKILL.md` 或脚本后，跑一次同步，保证三份一致：

```bash
bash scripts/sync-copies.sh            # 默认以 DSH 副本为源
bash scripts/sync-copies.sh <源目录>    # 或以指定目录为源
```

## License

[MIT](LICENSE)
