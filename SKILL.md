---
name: chaoxing-watch
description: 在学习通（超星）网页版按章节刷课，分两个互不调用的模块：① 课程模块——2 倍速 + 静音 + 最小化后台播完视频，以“任务点已完成”判完成；② 答题模块——全程前台、只靠截图读题，支持单选/多选/判断/填空/简答，答案由模型简单思考后自主给出；开跑前询问用户是否直接提交，交完不读分。Windows/macOS 两端都用 Edge 或 Chrome，且必须装 BrowserSkill 扩展；全程只用 bsk_*。
whenToUse: 用户要求“看学习通网课 / 刷任务点 / 看某门课第 x 章第 y 节 / 完成或提交某节章节测验 / 帮忙答题”时（课程不限）
---

# 学习通刷课（chaoxing-watch）

## 两个模块（先读这一节）

两个模块各有入口、运行方式和验收标准，**互不调用**：

| | **课程模块**（§1–§4、§6） | **答题模块**（§5、§6） |
| --- | --- | --- |
| 目标 | 视频任务点 | 章节测验 |
| 运行方式 | **后台**：起播后最小化 Agent Window | **全程前台**：不最小化、窗口可见 |
| 提交 | — | **开跑前先问用户**：直接交 / 先看（§5.0） |
| 读状态 | `bsk evaluate` 读 `{t,dur,paused,rate}` | **只靠截图**（页面文本被混淆，读不出原文） |
| 完成判据 | 页面出现 `任务点已完成` | 提交弹窗消失 + 标题 `已完成` |
| 汇报 | `<节名> 已播放完` | `<节名> 测验已提交` |

**分离原则**：

- 播放模块**不点** `2 章节测验`、不交卷、不读分；答题模块**不碰**播放器、不判任务点、不切回视频 tab。
- **一次只跑一个模块**，不并行：视频还在播时不要跑答题。
- 两模块**互不阻塞**：答题不检查视频是否播完，视频没播完也照答（目录数字可能仍是 `2`）。
- 共用 §0 环境自检、§7 故障恢复、§8 禁止；daemon/session 同一套，**窗口状态各自管**——从后台播放切到答题，先按 §5.1 把窗口还原到前台。

## 跑法：DSH 工具 / 任意 CLI（先对号入座）

同一个 skill，两种调用方式。本文正文用 **DSH 写法**（`bsk_*` 工具、`computer_*` 窗口工具）；换成 Codex / Claude Code / 终端时，按下表替换，流程和判据一个字都不用改。

| 环节 | DSH（BrowserSkill 插件） | 任意 CLI（Codex 等） |
| --- | --- | --- |
| 起会话 | `bsk_session start browser=<id> noFocus:false` | `bsk session start --browser <id> --width 1400 --height 800 --focus` → 记下 sid |
| 导航 | `bsk_page navigate <url>` | `bsk navigate --session <sid> <url>` |
| 观察 / 快照 | `bsk_inspect observe` / `snapshot` | `bsk observe --session <sid>` / `bsk snapshot --session <sid>` |
| 截图 | `bsk_inspect screenshot` | `bsk screenshot --session <sid> --out <png>` |
| 点击 | `bsk_interact click @eN` | `bsk click --session <sid> @eN` |
| 输入文本 | `bsk_interact fill target=@eN value="..."` | `bsk fill --session <sid> @eN --value "..."` |
| 读状态 | `bsk evaluate "<js>"` | `bsk evaluate --session <sid> "<js>"` |
| 滚动 | `bsk_interact wheel deltaY=400` | `bsk wheel --session <sid> --delta-y 400` |
| 缩窗 | `bsk_assist resize 1400x800` | `bsk window resize --session <sid> --width 1400 --height 800` |
| 最小化 | `computer_ui` 取「最小化」按钮 → `computer_ui_action invoke` | Windows：`scripts/win-minimize.ps1 -Title "<页面标题>" -Action minimize`；macOS：osascript（§9.2） |
| 还原 | `computer_ui` 取窗口节点 → `computer_ui_action action=restore` | 同脚本 `-Action restore` |
| 结束会话 | `bsk_session stop` | `bsk session stop <sid>` |

- 脚本参数里的「页面标题」先用 `bsk evaluate --session <sid> "document.title"` 读出来，传其中一段即可（包含匹配）。
- 脚本输出一行 JSON：`{"found":true,"hwnd":...,"iconic":true}`；**`iconic:true` 才算最小化成功**，`false` 就重试一次。
- Codex 跑 CLI 时必须 `-s danger-full-access`，否则命名管道被沙箱拦（§10）。
- 最小化后不要截图，读状态仍用 `bsk evaluate`（与 DSH 相同）。

## 前置环境（第一次用先过这一节，之后可跳过）

本 skill 只写“怎么刷”，不负责装环境。**转发给别人时，对方机器上要有下面四样**：

| # | 依赖 | 怎么确认 | 没有怎么办 |
| --- | --- | --- | --- |
| 1 | **Windows 10/11 或 macOS 13+**，浏览器用 **Edge 或 Chrome**，**必须装 BrowserSkill 扩展**（Firefox / Safari 不支持） | 能正常打开浏览器；扩展图标显示 Connected | 装 Edge 或 Chrome，再装扩展；没扩展的浏览器不算可用 |
| 2 | DeepSeek Harness，且能加载 skill | 会话的技能列表里能看到 `chaoxing-watch` | 把整个 `chaoxing-watch/` 文件夹放到 `~/.dsh/skills/` 下，重开会话 |
| 3 | **BrowserSkill（`bsk_*`）**：浏览器扩展（Edge / Chrome）+ `bsk` CLI + daemon | 工具列表里有 `bsk_*`；`bsk status` 能连通 | 见“前置 1”；**没有 bsk 就跑不了** |
| 4 | **超星（学习通）已登录**，且账号已选课 | 打开 `i.chaoxing.com` 直接看到“我学的课”，**不弹登录框** | 未登录 = **直接报错停止**，让用户自己登录后重跑；不代填账号密码、不试注册 |

### 前置 1 · BrowserSkill（`bsk_*`）：唯一通道

- **Edge 或 Chrome 里装 BrowserSkill 扩展**，确认图标显示 **Connected**（Edge 从 Edge Add-ons、Chrome 从 Chrome Web Store，同一套扩展）；
- 装 `bsk` CLI 并让它进 PATH：`bsk status` 能跑通；
  - Windows：`install.ps1`，常落在 `~/.cargo/bin/bsk.exe`；
  - macOS：官方 `install.sh`，默认 `~/.local/bin/bsk`，没有就 `export PATH="$HOME/.local/bin:$PATH"`；
- 报 `bsk CLI ("bsk") was not found` → 把 `bsk.exe` 复制到 `~/.cargo/bin/`（macOS 为把 `bsk` 放到 `~/.local/bin/`），或在配置里把 `bskPath` 指到实际路径（改完要重开 profile）；
- daemon 没起 → 跑 `scripts/bsk-daemon.sh`（幂等，见 §0.1；别指望自动拉起，宿主禁止 Job Object breakaway）。
- 会话的文件策略必须是 **danger-full-access**：`workspace-write` 沙箱会拦命名管道 `\\.\pipe\bsk-daemon-*`，此时 daemon 明明在跑也报 `拒绝访问 (os error 5)`，bsk 工具全部失效。（**Windows 专属**；macOS 无命名管道问题，可跳过这条。）

### 前置 2 · 一次性自检（装完跑一遍）

```text
bash $HOME/.dsh/skills/chaoxing-watch/scripts/bsk-daemon.sh   # daemon 就绪(幂等)
bsk browsers                            # ≥1 个 connected 实例，EXT 列有版本号
bsk_session start browser=<INSTANCE> noFocus=false
bsk_page navigate https://i.chaoxing.com/
bsk_inspect screenshot                  # 截到“我学的课”即就绪
```

- 任一步报 `not found` / `no browser endpoint`：按 §7 修 daemon/扩展；修不好就**报错停止**，别在环境上反复折腾。
- 这一节只在首次安装时做；日常开课走 §0 的每会话自检即可。

### 前置 3 · 未登录 = 报错停住（不猜不试）

**超星必须先登录**，本 skill 不处理登录。判定未登录的任一现象：

- 跳到 `passport2.chaoxing.com` / 出现账号密码登录框；
- 首页没有“我学的课”，只有“登录”按钮；
- 打开章节 URL 被弹回登录页。

命中任意一条，**立刻停止任务并报错**，一句话即可：

```text
学习通未登录，任务已停止。请在浏览器登录 i.chaoxing.com（登录后能看到“我学的课”）再让我继续。
```

不许做的事：代输账号密码、试验证码、点“注册/找回密码”、用别的账号登录、反复刷新碰运气。

## 速查（先看这张表）

### 通用

| 环节 | 动作 |
| --- | --- |
| 认环境 | 先跑 `scripts/bsk-daemon.sh`（§0.1）→ `bsk browsers` → 有实例就 `bsk_session start noFocus:false` → **先 resize 1400×800 再导航** → 冷启动就关掉普通窗口只留 Agent Window（§0.2.1） |
| 平台 | Windows 用 `computer_*` 管窗口（本文默认）；macOS 用 `osascript`（§9）。浏览器二选一：**装了 bsk 扩展的 Edge 或 Chrome** |
| 选模块 | 只看视频 → 课程模块（后台）；只做测验 → 答题模块（**前台**）；一次只跑一个 |
| 断了 | 报 `no endpoint` / `ensure daemon is running` → 跑 `scripts/bsk-daemon.sh` 重起 → 重开 session → 重导航章节 URL（§7） |

### 课程模块（后台播放，§1–§4）

| 环节 | 动作 |
| --- | --- |
| 进章节 | `i.chaoxing.com/` → **截图认课** → 目录里挑**橙色数字**的节（✓ 跳过）→ **视频** tab |
| 起播前 | 点“知道了” → 倍速 `2x`（回读确认）→ **静音** → **最小化 Agent Window** |
| 播放 | 后台起播 → `bsk evaluate` 读 {t, dur, paused, rate} → 按倍速算剩余 → sleep ≤110s 循环 |
| 判完成 | 页面出现 **`任务点已完成`**（目录 ✓ 交叉确认） |
| 收尾 | 输出一行 `<课程名> 已播放完` → 停住等用户决定是否下一集 |

### 答题模块（全程前台 + 截图，§5）

| 环节 | 动作 |
| --- | --- |
| 开跑前 | **问用户：答完直接提交，还是先给你看？**（非交互默认不提交） |
| 进测验 | 章节 URL → **窗口还原到前台** → 点 `2 章节测验` → 先看是否已完成（已完成就退） |
| 读题 | **只靠截图**；一屏不够就下滚再截 |
| 作答 | 选择/判断点 ref **截图确认变蓝**；填空/简答用 `fill` 写入并截图回读 |
| 提交 | 先看模式：截图给用户确认再交；直接模式：页面 `提交` → 弹窗再取 ref 点 `确定` → 回读弹窗消失 + `已完成` |
| 收尾 | 输出一行 `<节名> 测验已提交`（未交则 `已填完 N 题，待确认提交`）→ 不读分 |

三条不变式（课程模块）：**2 倍速**、**静音 + 最小化后台播**、**“任务点已完成”才算完**。
三条不变式（答题模块）：**全程前台不最小化**、**读题只靠截图**、**提交前先问用户**。

四条红线（上一轮翻车点，见 §0.3）：**不 stop session**、**先 resize 再怀疑播放器**、**不把 reload 当第一手段**、**播放中点控件前先重取 ref**。

## 0. 环境自检（skill 一被调用就跑一次，两个模块共用）

### 0.1 先确保 daemon 在跑（第一个动作，早于一切）

`bsk_*` 工具全靠本机 bsk daemon 转发；它不在，后面所有步骤都白搭。**每个会话第一步就跑这个脚本**，它幂等（已在跑时 0.4s 返回）：

```text
ops_bash: bash "$HOME/.dsh/skills/chaoxing-watch/scripts/bsk-daemon.sh"
```

- 退出码 `0` → daemon 就绪（输出带 pid 和 browsers 数），继续 §0.2；
- 退出码 `3` → 命名管道被沙箱拦截：换 `danger-full-access` 文件策略再跑，别原地反复重试；
- 退出码 `1` → 20s 没起来，读脚本打印的日志尾部，按 §7 处理；
- 退出码 `4` → 找不到 bsk，把 `bsk.exe` 放到 `~/.cargo/bin/`。
- 同一个脚本管收尾：任务结束跑 `bash …/bsk-daemon.sh stop`（见 §6.1）；`status` 只读探测。

为什么不能靠自动拉起：客户端默认会自己 spawn 一个 daemon（`BSK_AUTO_START`），但本宿主禁止 Job Object breakaway，自动拉起必然报 `cannot start an independent Windows daemon … os error 5`。所以脚本统一用 `bsk daemon start --foreground` + `nohup` 脱离 shell 起，并带 `--daemon-idle 2h`（默认只有 10 分钟，中途空太久会自己退出）。

- 插件报 `bsk CLI ("bsk") was not found`：`bsk.exe` 复制一份到 `~/.cargo/bin/`；`bskPath` 在 profile 补丁里指向实际路径（如 `$HOME/bin/bsk.exe`），改配置要重启 profile 才生效。
- daemon 被杀过之后，旧 `session` 会失联：`bsk_session list` 确认，然后重开一个。

### 0.2 再唤起浏览器（顺序第二）

浏览器没起来，后面全白搭；而且**后台窗口会被浏览器节流，视频会自动暂停**。固定开场：

```text
bsk browsers                      # 看有没有 connected 的实例
# 没有 → 打开浏览器（走用户 profile，保留登录态；Edge/Chrome 二选一，必须是装了 bsk 扩展的那个）：
#   Windows: app_launch  target: C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe
#                       或 target: C:\Program Files\Google\Chrome\Application\chrome.exe
#   macOS:   ops_bash    open -a "Microsoft Edge"   或   open -a "Google Chrome"
bsk browsers                      # 5–10 秒后复查，拿到 INSTANCE
bsk_session start browser=<INSTANCE> noFocus=false   # 关键：Agent Window 到前台
bsk_assist resize width=1400 height=800              # 在导航之前做，不是之后
```

- `noFocus: false` 不是可选项：`noFocus: true` 起的是后台窗口，学习通一旦判定页面不可见就暂停，进度还会被打回 0:00。**答题模块同样要 `noFocus: false`**，整个答题过程都不许最小化。
- 扩展状态确认：`bsk browsers` 里 EXT 列有版本号即已连接。
- 已经在跑的浏览器不用重开；Agent Window 是独立窗口，和你自己的标签页互不干扰。

#### 0.2.1 冷启动后收掉“普通窗口”（只剩 Agent Window）

`app_launch` 冷启动浏览器会先出现一个**普通窗口**（新标签页/恢复的标签），bsk 只能在随后创建的 Agent Window 里操作。收掉普通窗口，屏幕上就只剩一个窗口，而且正是 bsk 能用的那个。

**关键：在起 session 之前先把它的 hwnd 记下来**——那时浏览器只有一个窗口，不会认错（macOS 没有 hwnd，见 §9.3）：

```text
# 1. 冷启动浏览器、等扩展连上之后，先记下唯一的那个浏览器窗口
computer_windows filter=<msedge|chrome>   # 只有 1 个：hwnd=NORMAL，标题多为“新标签页”
# 2. 起 Agent Window（这一步之后会多出第二个浏览器窗口）
bsk_session start browser=<INSTANCE> noFocus=false
bsk_assist resize width=1400 height=800
# 3. 导航到章节页，让 Agent Window 有明确标题
bsk_page navigate <章节 URL>
# 4. 关掉第 1 步记下的那个 hwnd
computer_windows focus_hwnd=<NORMAL>
computer_key keys=alt+f4
# 5. 复查：浏览器仍连接 + 只剩一个浏览器窗口
bsk browsers
computer_windows filter=<msedge|chrome>
```

- **绝对不能关 Agent Window**：它是该浏览器最后一个窗口时，关掉 → 进程退出 → 扩展断线（`browser disconnected`）→ 所有 `bsk_*` 失效。
- 不要靠窗口尺寸认人：Agent Window 和普通窗口都可能是 2085×1191（最大化状态下 `resize` 的尺寸不体现），**只认第 1 步记下的 hwnd**。
- 关闭普通窗口会带走它里面的标签（可从浏览器历史恢复）；**窗口里有用户正在用的标签时先问一句**再关。
- 只在“本次冷启动出来的普通窗口”上做；浏览器本来就开着（有用户自己的窗口）时，**不要关任何用户窗口**，用完收尾 `bsk-daemon.sh stop` 即可。
- 原理：扩展挂在浏览器进程上；只要还剩至少一个窗口，进程就不退。

### 0.3 红线（上一轮实际翻车点）

| 红线 | 翻车现场 | 正确做法 |
| --- | --- | --- |
| **不 stop session** | 中途 `bsk_session stop` 想“重开一个更干净”，Agent Window 直接关闭、浏览器整个消失、bsk 工具链一起失效 | 要换参数就**再 start 一个新 session**；任务没结束绝不停 session |
| **先 resize 再怀疑播放器** | 816×753 时播放器纯黑、快照里根本没有 `播放视频` 按钮，reload 一次进度归零 | 宽度 <1200 时先 `resize ≥1400×800`；播放键 99% 是被挤到下沿/被浮层盖住 |
| **不把 reload 当第一手段** | reload 之后黑屏照旧，唯一效果是播放进度 0:00 | 顺序：resize → 清遮挡 → 等 5s → 再 reload |
| **播放中点击要先重取 ref** | 控制条 3 秒自动隐藏，旧 ref 点到已隐藏节点，白跑一轮 | 每轮快照 → 点击连做；点不动就重取 ref |

**答题模块的第五条红线**：**不许最小化**。最小化后截图 30s 超时，截图是本模块唯一的读题通道；被最小化就先还原（`computer_ui` 取窗口节点 → `action=restore ref=<窗口>`）+ `resize 1400×800` 再继续（§5.1）。

## 1. 课程模块·进入课程（一律从 i.chaoxing.com 起）

**入口固定 `https://i.chaoxing.com/`；课程不写死，用户说哪门就找哪门。**

**进门先验登录**：被跳到登录页 / 看不到“我学的课”，按“前置 3”**直接报错停止**。

```text
bsk_page navigate https://i.chaoxing.com/
bsk_assist resize width=1400 height=800
bsk_inspect screenshot            # 看“我学的课”卡片墙
```

### 1.1 截图认课（不依赖课程 id）

1. 先把“我学的课”滚到顶部，再截一张整屏。
2. 按**标题文字**找用户说的课，允许简写：说“高数”就匹配“高等数学A(1)”，说“大英”就匹配“大学英语（一）”。
3. 命中后：
   - 快照能列出 `link "课程名"` 时直接 `click` 它；
   - 只能看图时，点**卡片标题文字**——不是卡片右上角菜单，更不是左侧“考试列表/超星课表”。
4. 卡片没露出来就滚一屏**重新截**，别凭记忆点位置。

**多门同名 / 多个班**：按开课时间最近的进；仍不唯一就说明一句“有多门同名课，先按最新的走”，不要停在那里等。

### 1.2 目录里认节（已完成的一律跳过）

**先看对号：绿色 `✓` = 已完成，直接跳过，不点、不进、不重刷。**

进课程后右侧是章节目录，按用户的话定位：

- 给了节号（如 `1.1`）→ 找 `1.1`；若已是 ✓，说一句“该节已完成，跳过”，再做下一个未完成的；
- 只给标题关键词 → 按关键词匹配，同样先看是否 ✓；
- 什么都没给 → **从上往下找第一个仍显示橙色数字的节**；
- 用户明确说“重刷/再看一遍”才碰 ✓ 的节。

```text
bsk_inspect observe      # 目录里找 “1.1 …”，看行尾是 ✓ 还是橙色数字
# 不在视口 → 滚目录后再找，或截一张看位置
```

**橙色数字的含义**：该节还剩几个任务点（视频 1 + 测验 1 = 2）。**课程模块只做视频那一个**：做完视频数字从 `2` 变 `1`，页面出现 `任务点已完成` 即本节播放完成；剩下的测验任务点由**答题模块**（§5）独立处理。

### 1.2.1 顺序推进（一节接一节，仅视频）

```text
取第一个橙色数字的节 → 后台播放（§3）→ 读“任务点已完成”
  ├─ 已完成 → 输出“<课程名> 已播放完” → 停住等用户决定是否下一集
  └─ 未完成 → 回播放循环，别跳走
```

- **只清视频任务点**；测验任务点保持原样；
- 做完一节立刻回目录找**下一个**橙色数字的节，不要从头再扫；
- 已经完成的节不复查、不点开、不截图确认。

进“章节详情”后有两个 tab：`1 视频` / `2 章节测验`。**课程模块只点“视频”**。
播放器在两层 iframe 里，`observe` 看不到按钮，改用快照（会展开 iframe）拿 `button "播放视频"` 的 ref。

### 1.3 记 URL，后续节直接跳

章节页 URL 形如
`https://mooc1.chaoxing.com/mycourse/studentstudy?chapterId=<章节id>&courseId=<课程id>&clazzid=<班级id>&enc=<enc>`

- 第一次进节后把 `courseId / clazzid / enc` 记下来；
- 后续每一节只换 `chapterId` 再 `navigate`，省掉“课程 → 目录”两跳；
- **换课程必须重走 §1.1**，不要复用上一门课的 id。
- 答题模块也用同一套 URL 规则，但不复用播放模块的窗口状态。

## 2. 课程模块·起播前：清遮挡 → 时长 → 2 倍速

**顺序不能反**：浮层盖住的是播放器右下角，而倍速控件正好在那儿。

1. **先清遮挡**（见下表）。弹着“可边看边记…”就先点 **知道了**；右侧“Hi，XX：本课开放学习的 N 个任务点…”卡片点右上角 **×**。
2. **读时长**：截图一次，记 `当前/总时长`（如 `0:24 / 11:49`）。后续算进度只认这个总时长。
3. **设 2 倍速**：快照找 `button "播放速度 [has-submenu]"` → 展开菜单 → 点 `menuitemradio "2x"`。**必须回读两处**：菜单里 `2x` 变 `[checked]`、控制条文字变 `2x`。实测默认可能是 `0.75x`，不核对就会以为设成功了。只有 1.5x 时用 1.5x 并在汇报里注明。
4. 倍速控件被挡住时，先 `resize` 放大（≥1400×800）再点。
5. **静音**：快照找控制条上的 `button "静音"` → 点，回读为已静音。
6. 起播键是**视频正中央的大圆钮**（`button "播放视频"`），不是底部控制条那个小三角——小三角最容易被浮层压住。
7. 起播之后按 §3 最小化窗口、后台播放。

### 遮挡清单（谁盖住了播放器）

| 遮挡物 | 位置 | 处理 |
| --- | --- | --- |
| 笔记提示“可边看边记…” | 播放器右下角 | 点 **知道了**（点一次；没出去就重取 ref 补一次） |
| “Hi，XX：N 个任务点…” | 右侧目录区中下 | 点卡片右上角 **×**；也可能自己超时消失，别反复点 |
| “写笔记”按钮/面板 | 播放器右下 | 不写笔记就忽略 |
| “Agent 正在控制”条 | 窗口底部居中 | 不挡播放键；但**窗口缩小时会顶到播放器下沿** |
| 学习通吉祥物气泡 | 右下角 | 会挡住倍速下拉，先 `resize` 放大 |

**窗口尺寸红线**：Agent Window 默认约 1584×723，播放器宽约 1000px。宽度低于约 1200px 时，播放键会被下沿工具栏/气泡挤到遮挡区——**不要硬点，先 `resize` 到 1400×800 以上**。缩窗口只影响我们自己看，不影响已开始的播放。

> 这张清单同样适用于答题模块：测验页的浮层挡住选项或“提交”时，先清再点。

## 3. 课程模块·后台播放流程

**目标：让视频在后台自己走满，期间不占屏幕、不答题。** 一节的标准动作：

> 只处理**视频**任务点。遇到阅读、文档、PPT、讨论这类非视频节：不点、不猜，记一句“非视频任务点，跳过”就去做下一个橙色数字的节。

```text
# 1) 起浏览器（bsk browsers 为空时；Edge/Chrome 二选一，必须装了扩展）
app_launch  C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe
#    Chrome：app_launch C:\Program Files\Google\Chrome\Application\chrome.exe
#    macOS：ops_bash  open -a "Microsoft Edge" 或 open -a "Google Chrome"（§9.1）
# 2) bsk 打开页面并接管
bsk_session start browser=<INSTANCE> noFocus=false
bsk_assist resize width=1400 height=800
bsk_page navigate <章节 URL>
# 3) 关掉刚启动的那个普通浏览器窗口，只留 Agent Window（§0.2.1）
# 4) 播放准备：2x + 静音，两样都要回读确认
快照 → button "播放速度" → 点开 → menuitemradio "2x" → 回读 [checked] + 控制条 2x
快照 → button "静音"     → 点 → 回读已静音
# 5) 最小化 Agent Window：先取标题栏“最小化”按钮的 ref，再 invoke
#    （实测：只给 hwnd + action=minimize 会报 BAD_REQUEST，必须带 ref）
computer_ui hwnd=<AgentWindow> filter=最小化
computer_ui_action action=invoke ref=<“最小化”按钮的 ref>
#    任意 CLI：scripts/win-minimize.ps1 -Title "<document.title>" -Action minimize（回读 iconic:true）
#    macOS：osascript -e 'tell application "Microsoft Edge" to set miniaturized of window 1 to true'（§9.2）
# 6) 后台起播，并读起点与总时长
快照 → button "播放视频"/"播放" → 点
bsk evaluate 一次读齐 {currentTime, duration, paused, playbackRate}
```

- 最小化之后**不要截图、不要 resize**：截图在最小化下会 30s 超时，读状态一律用 `bsk evaluate`。
- 起播后必须回读 `paused === false` 且 `playbackRate === 2`，否则补点播放/重设倍速再继续。

### 3.1 轮询节奏（按倍速算）

- 2x 下 `预计实际耗时 ≈ (duration − currentTime) / 2`；
- `ops_bash` 前台单次上限 120s，**每次等待 ≤110s**；
- 剩余很长时不要密集轮询，只在最后阶段加密：

| 剩余（按 2x 折算的实际时间） | 等待 |
| --- | --- |
| > 3 分钟 | `sleep 100`，循环 |
| 1–3 分钟 | `sleep 60` |
| < 90 秒（**临结束监控**） | `sleep 20–30`，并把窗口 `restore` 唤起，盯住收尾 |
| 读到 `paused:true` | 先补点一次播放（快照 → 点），再继续等 |

一轮就是：

```text
bsk evaluate 读 {t, dur, paused, rate}
   ├─ paused → 快照取“播放”ref → 点 → 记新起点
   ├─ t/dur ≥ 0.97 → 进入结束判定（§4）
   └─ 否则 → sleep（按上表）→ 下一轮
```

### 3.2 结束判定：只看“任务点已完成”

- 页面出现 `option "任务点已完成"`（正文“完成条件…”下方那块）即视为该节**视频任务点完成**；
- 目录里该节的橙色数字消失或变 ✓ 作为交叉确认；
- 完成后立刻收手：**不点章节测验、不读分**——答题是 §5 的独立模块。

## 4. 课程模块·完成判定（任务点已完成）

| 状态 | 含义 |
| --- | --- |
| `option "任务点未完成"` / 目录橙色 `2`、`1` | 还没看完，继续播 |
| **`option "任务点已完成"`** | 本节播放任务完成（✓ 可交叉确认） |

- 读法：`bsk evaluate` 读播放器状态与任务点文案，不用为看一眼去截图。
- 进度 ≥90% 只是必要条件，**“任务点已完成”才是通过条件**。
- 已经完成的节不碰（§1.2）；只做橙色数字的节，按目录顺序推进。
- 进度回 0:00 / 切 tab 重载属正常，点播放会从服务端进度续播。

## 5. 答题模块·章节测验（全程前台 + 截图）

> **独立模块。** 与课程模块（§1–§4）互不调用：播放模块不点测验，本模块不碰播放器。
> 与播放相反：**全程前台**、不最小化；**题干与选项只从截图读**（页面文本被私有字体混淆，读出来是乱字）。
> **题型不限于选择/判断**：单选、多选、判断、填空、简答（含名词解释、论述）都要做，答案一律由模型按学科常识自己给，不查资料。
> **开跑前先问用户**（§5.0）：答完直接交还是先给人看，由用户当场决定。

### 5.0 开跑前：问一句“是否直接提交”

动第一道题之前，先确认提交方式，**整轮不变**：

| 环境 | 做法 |
| --- | --- |
| 交互（DSH 对话等） | 直接问用户：**“答完直接提交，还是先给你看答案？”** 等回答再开始；用户说“直接交/别问了”就按直接提交走 |
| 非交互（`codex exec` 等无法回话） | **默认不提交**：填完、截图、停住，等用户下一条指令说“提交”；除非任务里已明确写“直接提交” |

- 用户选「先看」→ 走 §5.5 的“先确认后提交”分支；
- 用户选「直接提交」→ 走 §5.5 的“直接提交”分支；
- 中途不许改主意、不许两种混用。

### 5.1 前台就位（本模块第一步）

```text
# 0) daemon / 浏览器 / session 见 §0.1–§0.2；从播放模块切过来时，窗口多半是最小化的
#    Windows（本节默认）：
computer_windows filter=<msedge|chrome>           # 拿到 Agent Window 的 hwnd
computer_ui hwnd=<AgentWindow>                    # 读窗口节点
computer_ui_action action=restore ref=<Window 节点 ref>   # 最小化状态先还原（只给 hwnd 会报 BAD_REQUEST）
computer_windows focus_hwnd=<AgentWindow>
#    任意 CLI：scripts/win-minimize.ps1 -Title "<document.title>" -Action restore
#    macOS：osascript 还原 + activate，见 §9.2
bsk_assist resize width=1400 height=800           # 一次调好，别边答边缩
bsk_page navigate <章节 URL>
bsk_inspect screenshot                            # 能出图（<5s）即前台就绪
```

- **全程不许最小化**：最小化后截图 30s 超时，等于失去唯一读题通道；缩到 <1200 宽也会让选项/提交被挤走。
- 保持 1400×800，答题过程中别再动窗口。
- 已经还原但仍不出图 → 按 §7“答题截图超时”处理。

### 5.2 进入测验

- 用户给了节号/标题 → 直接 `navigate` 该节 URL（只换 `chapterId`，同门课复用 `courseId/clazzid/enc`，§1.3）；
- 没给 → 目录里从上往下找还有测验待做的节（视频已完成时橙色数字通常剩 `1`，即测验；数字 `2` = 视频也没做，**仍可先答**）；
- **先看状态再动手**：点进 `2 章节测验` 后，标题旁已显示 `已完成` / `本次成绩` → **直接退出，不重做**，说一句后看下一节。

```text
bsk_inspect screenshot        # 确认 tab 与页面位置
bsk_inspect snapshot          # 取页面顶部 button "章节测验" 的 ref
→ click
bsk_inspect screenshot        # 确认已进测验页 + 标题状态（已完成就退出）
```

- **点一次没切过去是常见现象**（iframe 还没就绪）：重取 ref 再点一次；不要因此 reload。
- 测验页标题里的节号可能和目录编号不一致（目录 `4.1`、测验页 `16.1`），按课程名 + 题干确认，别以为走错节。
- **有的课程没有 `2 章节测验` tab**（测验放在「作业」或「考试」里）：那就不属于本模块，报告“本节无章节测验，跳过”，不要自己去作业/考试页乱点。

### 5.3 读题：只靠截图

1. 整屏截一张，先数题、认题型：**单选 / 多选 / 判断 / 填空 / 简答（含名词解释、论述）**。
2. **题干、选项、空格都只从截图读**；页面文本被混淆，读不出原文，不要试图从文本里拼题。
3. 一屏放不下就下滚再截：`bsk_interact wheel deltaY=400`；**只往下滚，别来回滚**（回滚会重排，ref 失效）。
4. 题干长/字小看不清时裁剪截图：`bsk_inspect screenshot ref=<题目容器>`。
5. 截图糊/被浮层挡 → 先复截，再按 §2 遮挡清单清（知道了 / ×）；仍不行才 reload 章节页——**reload 会丢已选答案，只在尚未作答时用**。

### 5.4 作答之一：选择 / 判断（ref 点击）

1. 快照一次拿到整页 `radio` / `checkbox` 的 ref（**不用滚动也能点**，ref 是全页的）。
2. 选项按钮的名字形如 `radio "A … 选择"`，**用字母 A/B/C/D 定位**；判断题是 `对选择` / `错选择`。哪个字母对应哪段文字，仍以截图为准。
3. 单选/判断：点对应 ref；**点完立刻截图确认圆圈变蓝**。
4. 多选：逐个点每个 `checkbox`，全部点完再截一张核对（漏点一项就是错题）。
5. 点不动 / 不变蓝：**重取 ref 再点**；仍不蓝就点该选项的 label 文本 ref。

### 5.4.1 作答之二：填空 / 简答（文本输入）

1. 快照里找文本框：填空题一般是 `textbox`（`input` / `textarea`），简答是 `textarea` 或 `contenteditable`。名字通常是空的，按**从上到下的顺序**对应题号。
2. 写入答案：
   - DSH：`bsk_interact fill target=@eN value="<答案>"`
   - CLI：`bsk fill --session <sid> @eN --value "<答案>"`
3. **多个空格逐个填**；有编号的空（如 `①____②____`）按顺序对号。
4. **不要按回车**——有的页面回车会触发表单提交。
5. 回读：截图确认文字进了对应的框（字小就裁剪该题截图）。
6. 填不进去（富文本编辑器）：先 `click` 一次编辑区再 `fill`；仍不行就点 `contenteditable` 的 ref 重试一次。
7. **答案由模型自己给**：
   - 填空：**关键词/术语**，1–8 字，只写答案本身，不写"答："；
   - 简答/名词解释：**2–3 句、点到为止**，先给定义/结论再补一句解释；
   - 不编造出处、不写"根据教材/如上所述"这类套话，也不留空。

### 5.4.2 通用答题纪律：简单思考，不纠结

1. **简单思考**：读完题先想一下——能一眼定的直接定；需要推的做一两步推理或排除，再落答案。
2. **不深挖**：不翻书、不查网、不大段分析、不反复推敲；同一题不改第二遍。
3. 拿不准时给**最主流、最保守**的答案，不留空、不写“不会”。
4. 填完扫一眼：**有没有漏题、有没有把答案填错框**——只查这两样，不逐题复查对错。

### 5.5 提交：先看模式 / 直接模式

**A. 先确认后提交**（用户选了「先看」，或非交互环境默认）

1. 全部填完后 `bsk_inspect screenshot` 截一张，能看清题与已填内容；
2. 停下，向用户说明：**“已填完，共 N 题，确认提交？”**（非交互环境就到这里等指令）；
3. 用户说“交”→ 转 B；用户要改 → 只改他指出的题，然后重新截图确认。

**B. 直接提交**

1. 点页面底部 `button "提交"` → 弹出 `alertdialog "提示"` / `确认提交？`。
2. **重新快照**取弹窗内的按钮再点——**绝不能复用页面那个“提交”的 ref**（会点到背景按钮上）。注意：弹窗按钮**屏幕上是「提交」、快照里叫「确定」**，按后者取 ref。
3. 回读两个信号：**弹窗消失** + 标题变成 `已完成`（目录里该节随即可见 ✓）；两个都有才算提交成功。
4. 弹窗还在 = 没点上：重取弹窗 ref 再点一次，别重复点页面“提交”。
5. **交完就走**：不读分、不核对正确率、不复盘题目、不切回视频 tab（切回会让播放器重载回 0:00）。

### 5.6 汇报：一行，不读分

已提交：

```text
1.1 课程导论 测验已提交
```

待确认（先看模式还没交）：

```text
1.1 课程导论 已填完 4 题，待确认提交
```

- 只输出这一行，不贴截图、不 `present`、不报分数/正确率/正确题数；
- 多节连答按行输出，一行一节；
- **默认停住**等用户决定是否下一节；用户明确说“全部/连着答”才按目录顺序继续；
- 全部答完按 §6.1 收尾（关 daemon）。

### 5.7 控件与坑（实测）

| 控件 | 坑 | 做法 |
| --- | --- | --- |
| 单选/多选 | 圆圈是自定义控件，点外层容器不变蓝 | 取 `radio` 的 ref → 点 → 截图确认变蓝；多选逐个点 |
| 填空 / 简答 | 输入框可能是 `input`/`textarea`，也可能是富文本 `contenteditable`；有的要聚焦后才可写 | 先点一下编辑区再 `fill`；多空逐个填；回读截图确认；不按回车 |
| 提交 | 页面一个“提交”，弹窗一个“提交/确定”，ref 不能混用 | 先点页面“提交”，再取弹窗内 ref 点；回读弹窗已消失 |
| 题干/选项 | 私有字体混淆，文本全是乱字 | 只认截图；看不清就裁剪截图 |
| 切 tab | 从测验切回视频，播放器重载回 `0:00`（服务端进度还在） | 本模块不切回视频；要继续播下一节交回课程模块 |
| 窗口 | 最小化后截图 30s 超时 | 全程前台；被最小化先 restore + resize 再继续 |

**滚动**：一次快照就能拿到整页全部 `radio` ref，**不用滚动也能点**；要读下面的题就下滚再截图，别来回滚。

## 6. 汇报（两个模块各一句）

**课程模块**：播到 `任务点已完成` 后，**只输出一行**：

```text
1.1 课程导论 已播放完
```

**答题模块**：提交成功（弹窗消失 + 标题 `已完成`）后，**只输出一行**：

```text
1.1 课程导论 测验已提交
```

- **不出截图、不 `present`、不报分数/正确率/正确题数**；完成就是唯一交付物；
- 多节按行输出，一行一节；
- 各自播完/答完**停住等用户决定是否下一节**：不要自动答题、不要自动跳下一节、不要自动切模块；
- 只有出异常时才多写一句（`异常：xxx，已用 xxx 处理`）。

### 6.1 收尾：任务结束就把 daemon 关掉

最后一行汇报发完、确认本任务**没有待做的节**之后，显式关闭 daemon：

```text
ops_bash: bash "$HOME/.dsh/skills/chaoxing-watch/scripts/bsk-daemon.sh" stop
```

- 关的是本机 bsk daemon：Agent Window 与浏览器 session 一起释放，浏览器本身不退出；下次跑 §0.1 会重新拉起（约 1–2s）。
- **只在任务真的结束时调**：中途停会让下一个 `bsk_*` 调用报 `no endpoint`。
- 用户说“等会儿继续”“先别关”，或明显还要刷/答下一节 → **不关**。
- 不要指望空闲自动退出：扩展连着时 daemon 能挂几十分钟不退，所以“结束就关”只能靠显式 `stop`。

## 7. 故障恢复（两个模块共用）

| 现象 | 处理 |
| --- | --- |
| `session not registered` | daemon 重启过；`bsk_session list` → 重开 session → **再导航一次章节 URL**（别重新走课程列表） |
| `ensure daemon is running` / `no browser endpoint` / 工具全挂 | daemon 掉了：跑 `scripts/bsk-daemon.sh`（§0.1）→ `bsk status` 复查 → 重开 session |
| 没有 connected 的浏览器 | `bsk browsers` 为空 → `app_launch` 起 Edge/Chrome → 等 5–10 秒复查 → 再 start session |
| **bsk 工具没反应/报错，但 `bsk status` 正常** | **先开浏览器**（`app_launch` 指到 `msedge.exe` 或 `chrome.exe`），别先重启 daemon：浏览器一退出，Agent Window 跟着没，daemon 日志会写 `session removed: user closed Agent Window` + 紧接着 `browser disconnected`；扩展 5–10s 重连后重试原命令 |
| Agent Window 自己消失 | 先看 `~/.bsk/daemon.log.<日期>`：`idle session stopped` = `--session-idle` 到期（默认 5 分钟，脚本已改成 2h）；`user closed Agent Window` = 窗口被外部关掉 |
| 命名管道 `拒绝访问 (os error 5)` | 会话文件策略不是 `danger-full-access`——沙箱拦了 `\\.\pipe\bsk-daemon-*`；改策略后重跑脚本（Windows 专属） |
| macOS：osascript 窗口动作无效 / 提示无权限 | 见 §9.5：给运行 DSH 的终端开“辅助功能”；`miniaturized` 不生效就退化为不最小化 |
| 播放器纯黑 / 没有 `播放视频` 按钮 | 先 `resize ≥1400×800`；再清浮层；等 5s 重截；都不行才 reload |
| 视频总在几十秒后自己停 | 最小化/后台时偶发；`bsk evaluate` 读到 `paused` 就补点一次播放。持续异常再把窗口 restore 到前台 |
| ref 失效 / 点不中 | 重新快照取 ref，别复用上一轮；控制条隐藏时更必须重取 |
| 进度回 0:00 / 切 tab 后从 0 开始 | 播放器重载，属正常；点播放会按服务端进度续播，不用重刷整节 |
| 播放键点了没反应 | 先关浮层，再看是否真在播；仍不动则重进章节页 |
| 倍速点不到 / 默认不是 2x | 先 resize + 清遮挡再点；**点完必须回读** `menuitemradio "2x" [checked]` + 控制条 `2x` |
| 目录没显示 ✓（其实已完成） | 目录刷新滞后：reload 一次章节页再读；以快照里的 `2.3 已完成` 为准 |
| **答题截图 30s 超时** | 窗口被最小化/挂起：`computer_ui` 取窗口节点 → `action=restore ref=<窗口>` → `resize 1400×800` 再截；仍超时说明 session 掉了，重开 session 重导航 |
| 选项点了不变蓝 | 重取 ref（别复用）；仍不蓝就点该选项的 label 文本 ref；不行再清浮层 |
| 滚动后 ref 失效 | 滚动会重排，重新快照再点（§5.4） |
| 提交后弹窗不关 | 弹窗按钮是 `确定`（屏幕上 `提交`）；重取弹窗内 ref，回读 `确认提交？` 已消失 |
| 提交后标题仍“未完成” | 可能只是没确认：重取弹窗 ref 再点；确已提交则 reload 章节页只读确认（**不重答**） |
| 截图太占 token | 用 `bsk_inspect screenshot ref=<播放器/题区/目录>` 裁剪；整屏只在认课/认页时用 |

## 8. 禁止

### 通用

- **只用 bsk**：起不来就按 §7 修，修不好**报错停止**。
- **只用装好 bsk 扩展的 Edge 或 Chrome**，二选一后本任务就固定用它；不许临时换浏览器、不许用没装扩展的浏览器。
- 被遮挡就先放大窗口、清浮层，再点；**不许硬点被盖住的位置**。
- **任务没结束不许 `bsk_session stop`**；要换参数就再开一个新 session。
- **不许把课程写死**：入口永远是 `i.chaoxing.com/`，课程按用户当前说的那门重新截图认；上一门课的 `courseId/clazzid/enc` 一律不复用。
- 不许拿截图当汇报：完成情况一行字，除非用户要证据。
- 没有页面证据，不许声称“播放完 / 任务点已完成 / 测验已提交”。

### 课程模块

- 不许拖进度条、不许跳着看、不许伪造进度。
- **不许点“章节测验”、不许提交答案、不许读分**——答题是 §5 的独立模块。
- **不许重刷已完成的节**：✓ 的节不点开、不进、不截图确认；只做橙色数字的，并按目录顺序推进。
- 一节没播完（视频任务点仍“未完成”）不许跳到下一节。

### 答题模块

- **全程前台，不许最小化、不许后台运行**。
- **题干与选项只从截图读**，不许猜题、不许对乱字做“合理推测”。
- **开跑前必须问“是否直接提交”**；用户选「先看」或无法回话时，**未经确认不许点提交**。
- **不许留空题**：填空、简答也要答，答案由模型按学科常识给，不查资料、不编出处。
- 简单思考可以，但**不许翻书/查网/反复推敲/同一题改第二遍**。
- 填空只写关键词/术语，简答 2–3 句点到为止，不许写“根据教材”“如上所述”这类套话。
- 交完就走：**不读分、不报正确率、不复盘题目**，不许切回视频 tab“确认一下”。
- 不许 reload 已作答的测验页（会丢答案）。

## 9. macOS 分支（Windows 流程不变）

> 只有“开浏览器、窗口最小化/还原/关闭”这三类动作与 Windows 不同；`bsk_session`、`bsk_page`、截图、快照、`evaluate`、轮询节奏全部照用。
> 前提：macOS 13+、**装了 bsk 扩展的 Edge 或 Chrome**、`bsk` 在 PATH（`install.sh` 默认 `~/.local/bin`）。

### 9.1 起浏览器

```text
# 二选一，选装了扩展的那个
ops_bash: open -a "Microsoft Edge"
ops_bash: open -a "Google Chrome"
# 都不行就用完整路径：open -a "/Applications/Microsoft Edge.app" / open -a "/Applications/Google Chrome.app"
bsk browsers                              # 5–10 秒后复查，EXT 列有版本号
```

### 9.2 最小化 / 还原（替代 `computer_*` 窗口动作）

先定这次用哪个浏览器（要和 `bsk browsers` 里连上的那个一致），后面所有窗口动作都指向同一个应用：

```bash
APP="Microsoft Edge"      # 或 APP="Google Chrome"

# 看窗口标题，确认哪个是 Agent Window
osascript -e "tell application \"$APP\" to get name of windows"

# 最小化（课程模块起播后）
osascript -e "tell application \"$APP\" to set miniaturized of window 1 to true"
osascript -e "tell application \"$APP\" to get miniaturized of window 1"    # 回读 true

# 还原 + 置前（答题模块 §5.1）
osascript -e "tell application \"$APP\" to set miniaturized of window 1 to false"
osascript -e "tell application \"$APP\" to activate"
```

- `window 1` 不一定是 Agent Window。分不清就先 `bsk_page navigate` 到章节页，让 Agent Window 有明确标题，再按标题定位：

  ```bash
  osascript -e "tell application \"$APP\" to set miniaturized of (first window whose name contains \"章节\") to true"
  ```

- **回读是硬要求**：`miniaturized` 为 `true` 才算最小化成功；没生效就按 9.2.1 退化。
- 最小化后不要截图、不要 resize——和 Windows 一样，读状态用 `bsk evaluate`。

#### 9.2.1 退化（`miniaturized` 不生效时）

不最小化，改为**保持前台、让窗口被别的窗口盖住**：视频仍在播（遮挡不等于隐藏）。若仍被判不可见而暂停，`bsk evaluate` 读到 `paused` 就补点一次播放；汇报时注明“macOS 未最小化”。

### 9.3 冷启动的普通窗口（可选）

macOS 没有 hwnd，`computer_windows` 用不了：

- **默认不关**：bsk 只操作 Agent Window，普通窗口留着不影响功能；
- 要关就按标题，别按序号：

  ```bash
  osascript -e "tell application \"$APP\" to close (every window whose name is \"新标签页\")"
  ```

- **绝不能关 Agent Window**：它若是该浏览器最后一个窗口，关掉 = 进程退出 = 扩展断线。

### 9.4 路径与平台差异

| 项 | Windows | macOS |
| --- | --- | --- |
| 浏览器 | Edge `...\msedge.exe`；Chrome `...\chrome.exe` | `open -a "Microsoft Edge"` / `open -a "Google Chrome"` |
| bsk 位置 | `~/.cargo/bin/bsk.exe` | `~/.local/bin/bsk`（install.sh 默认） |
| 窗口动作 | `computer_windows` / `computer_ui_action` | `osascript`（§9.2） |
| 沙箱 | 必须 `danger-full-access`（命名管道） | 无此问题，可忽略 |
| daemon 脚本 | 照跑 | 照跑（bash，自带 3.2 够用） |
| 日志 | `~/.bsk/daemon.log.<日期>` | 同 |

### 9.5 macOS 已知坑

| 现象 | 处理 |
| --- | --- |
| osascript 提示不允许控制 / 无权限 | 系统设置 → 隐私与安全性 → 辅助功能，给运行 DSH 的终端（或 DSH 本体）授权后重试 |
| `miniaturized` 报错或回读 false | 浏览器版本对 AppleScript 支持不同；走 9.2.1 退化，不要反复重试 |
| `open -a` 失败 | 用完整路径 `.app`；确认装的是 Edge 或 Chrome，且扩展在里面 |
| 截图 30s 超时 | 同 Windows：窗口被最小化/挂起；还原后再截（§9.2） |
| Safari / Firefox | 不支持；只认装了 bsk 扩展的 Edge 或 Chrome |

## 10. 任意 CLI（Codex 等）

> 正文是 DSH 写法；换 CLI 只看「跑法」那张表。本节只记 Codex 特有的坑（实测 codex-cli 0.164.0）。

### 10.1 安装

```text
npm i -g @openai/codex          # 得到 codex 命令
codex --version
```

- 技能目录：`~/.agents/skills/`（把本目录整个拷进去即可）；
- 通用浏览器技能可另装：`bsk install-skill --harness codex`（或 `--all`）；
- 本机的 bsk 若不在 PATH：`export PATH="$HOME/.local/bin:$PATH"`。

### 10.2 沙箱（必须放开）

`codex exec` 默认 `-s read-only`，bsk 会先报 `could not determine user home directory`；只设 `BSK_HOME=%USERPROFILE%\.bsk` 只能解决第一层，接着会撞命名管道 `拒绝访问 (os error 5)`。

**跑刷课任务必须：**

```text
codex exec -s danger-full-access --skip-git-repo-check - < prompt.txt
```

### 10.3 窗口

- Codex 没有 `computer_*`，`bsk window` 也只有 `resize`；
- 最小化 / 还原用 `scripts/win-minimize.ps1`（Windows）或 `osascript`（macOS），见「跑法」表；
- 脚本靠页面标题定位窗口，标题用 `bsk evaluate --session <sid> "document.title"` 取。

### 10.4 提交确认在 Codex 里怎么落

`codex exec` 是**非交互**的，用户不能在跑到一半时回话，所以按 §5.0 走默认分支：

- 默认：**答题只填不交**，最后一行报 `已填完 N 题，待确认提交`；
- 要自动交，就在 prompt 里显式写“答题部分直接提交”，别指望它自己猜。

### 10.5 实测（2026-10）

一节「任意课程」的章节：课程模块 2 倍速播放 30 秒（`paused=false`、`rate=2`），答题模块 3 题按截图作答并提交成功，全程约 12 万 token。截图直接由 Codex 读取，无需额外 OCR。

## 11. 维护：三份副本必须同步

本 skill 同时存在三处，改完必须一起更新：

| # | 位置 | 用途 |
| --- | --- | --- |
| 1 | `~/.dsh/skills/chaoxing-watch` | DSH 工作副本（通常在这里改） |
| 2 | `~/.agents/skills/chaoxing-watch` | Codex 副本 |
| 3 | `~/Desktop/chaoxing-watch` | 开源仓库（含 README / LICENSE） |

```bash
bash ~/Desktop/chaoxing-watch/scripts/sync-copies.sh          # 默认以 DSH 副本为源
bash ~/Desktop/chaoxing-watch/scripts/sync-copies.sh <源目录>  # 或以指定目录为源
```

- 脚本逐份复制 SKILL.md + `scripts/` 两个脚本，并用 `diff` 校验，每行输出 `OK` 才算同步完成；
- README、LICENSE、.gitignore 只留在仓库，不进技能目录；
- **改完 skill 必须跑一次同步**，否则 Codex 和开源仓库会停在旧版本。
