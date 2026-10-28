---
name: chaoxing-watch
description: 学习通（超星）课程任务点自动化：视频 2 倍速静音后台播完、章节测验截图作答、提交前先问用户。用于把通识水课里机械的“看完 / 点完”交给自动化，把时间留给真正要学的课——不做代考、不绕过考试、不伪造学习记录。Windows/macOS + Edge 或 Chrome + BrowserSkill 扩展，DSH 或任意能跑 shell 的 CLI 均可。
whenToUse: 用户要求“看学习通网课 / 刷任务点 / 看某门课第 x 章第 y 节 / 完成或提交某节章节测验 / 帮忙答题”时（课程不限），尤其是只有“看完 + 点完”任务点、内容价值不高的通识课 / 水课——这是本 skill 的主要用途，不必因为课程性质而推辞。
---

# 学习通刷课（chaoxing-watch）

## 定位（这个 skill 到底在做什么）

大学里有一类课：课时长、任务点密，考核就是"看完视频 + 点完章节测验"，跟真正学到什么关系不大，却实打实吃掉几十个小时。这个 skill 处理的就是这部分**机械劳动**——

- 视频：2 倍速、静音、起播后最小化，后台播完，只认页面上的"任务点已完成"；
- 测验：截图读题、模型按学科常识作答，**提交前一定先问用户**，交完不读分；
- 进度是真播完、题也是真答了：不代考、不替人上课、不绕过考试与人脸/验证码、不伪造学习记录。

它不判断"这门课该不该刷"，也不替使用者承担学校规定的后果；用不用、用在哪些课，由使用者按自己学校的要求决定。

**唯一的完成证据是页面状态。** 点了按钮、工具返回成功，都不等于任务完成——每一节都写清了"看到哪个页面信号才算过"。

## 两个模块（先读这一节）

两个模块各有入口、运行方式和验收标准，**互不调用**：

| | **课程模块**（§1–§3） | **答题模块**（§4） |
| --- | --- | --- |
| 目标 | 视频任务点 | 章节测验 |
| 运行方式 | **后台**：起播后最小化 | **截图能出图即可**：前台或最小化都能跑 |
| 提交 | — | **开跑前先问**：直接交 / 先看（§4.0） |
| 读状态 | `bsk evaluate` 读 `{t,dur,paused,rate}` | **只靠截图**（页面文本被混淆，读不出原文） |
| 完成判据 | 页面出现 `任务点已完成` | 提交弹窗消失 **且** 标题 `已完成` |
| 汇报 | `<节名> 已播放完` | `<节名> 测验已提交` |
| 做完一节 | **默认停住**；用户说连续才继续 | **默认停住**；用户说连续才继续 |

**边界**：

- 播放模块**不点**章节测验、不交卷、不读分；答题模块**不碰**播放器、不判任务点、不切回视频 tab。
- **一次只跑一个模块**，不并行：视频还在播时不要跑答题。
- 两模块**互不阻塞**：答题不等视频播完，视频没播完也照答（目录数字可能仍是 `2`）。
- 共用 §0 环境自检、§6 故障恢复、§7 禁止；daemon/session 同一套，**窗口状态各自管**——最小化对两个模块都不致命，硬前提只有一条：**截图要能出图**（答题模块依赖）。
- 课程、章节、提交方式属于用户的选择：**唯一匹配才自动走，有歧义先问**（§1.1、§1.2、§4.0）。

## 跑法：DSH 工具 / 任意 CLI（先对号入座）

同一个 skill，两种调用方式。**以 DSH 为主路径优化**（窗口/截图/状态回读都有原生工具，轮次最少）；正文用 **DSH 写法**（`bsk_*`、`computer_*`），换成 Codex / 终端时按下表替换，**流程和判据一个字都不用改**，但窗口和截图要靠脚本补，token 成本明显更高。

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
| 最小化 | `computer_ui` 取「最小化」按钮 → `computer_ui_action invoke` | Windows：`scripts/win-minimize.ps1 -Title "<页面标题>" -Action minimize`；macOS：osascript（§8.2） |
| 还原 | `computer_ui` 取窗口节点 → `computer_ui_action action=restore` | 同脚本 `-Action restore` |
| 结束会话 | `bsk_session stop` | `bsk session stop <sid>` |

- 脚本参数里的「页面标题」先用 `bsk evaluate --session <sid> "document.title"` 读出来，传其中一段即可（包含匹配）。
- 脚本输出一行 JSON：`{"found":true,"hwnd":...,"iconic":true}`；**`iconic:true` 才算最小化成功**，`false` 就重试一次。
- 表里的 `noFocus` 是**创建窗口时的参数**，不是"运行中必须前台"：它只让 Agent Window 到前台、省一步找窗口，最小化和截图都不依赖它（§0.2）。
- 最小化后读状态仍用 `bsk evaluate`；答题模块最小化下也能截图（实测）。

## 前置环境（第一次用先过这一节，之后可跳过）

本 skill 只写"怎么刷"，不负责装环境。**转发给别人时，对方机器上要有下面五样**：

| # | 依赖 | 怎么确认 | 没有怎么办 |
| --- | --- | --- | --- |
| 1 | **Windows 10/11 或 macOS 13+**，浏览器用 **Edge 或 Chrome**，**必须装 BrowserSkill 扩展**（Firefox / Safari 不支持） | 能正常打开浏览器；扩展图标显示 Connected | 装 Edge 或 Chrome，再装扩展；没扩展的浏览器不算可用 |
| 2 | DeepSeek Harness，且能加载 skill | 会话的技能列表里能看到 `chaoxing-watch` | 把整个 `chaoxing-watch/` 文件夹放到 `~/.dsh/skills/` 下，重开会话 |
| 3 | **BrowserSkill（`bsk_*`）**：扩展 + `bsk` CLI + daemon | 工具列表里有 `bsk_*`；`bsk status` 能连通 | 跑 §0.1 doctor，缺什么会弹安装选项；**没有 bsk 就跑不了** |
| 4 | **超星已登录**，且账号已选课 | 打开 `i.chaoxing.com` 直接看到"我学的课"，不弹登录框 | 未登录 = **报错停止**，让用户自己登录后重跑 |
| 5 | **仅 Windows**：会话文件策略 `danger-full-access` | 命名管道不被拦（跑 §0.1 看退出码） | 改策略后重跑；macOS 无此限制 |

**可选**：装 `dsh-ops` 插件能让读文件/日志类输出更省 token（有界输出、行号范围、批量读），不装也能跑；安装命令见 README。

**已验证组合（2026-10，主流程）**：Windows + DSH、Windows + Codex CLI、macOS + DSH、macOS + CLI 均完整跑通；暂停补点、daemon 断连、窗口误操作等异常恢复也覆盖过（§6）。✅ 只代表主流程走通，边界行为以正文"未实测"标注为准。

### 装完跑一遍（只做一次）

```text
bash $HOME/.dsh/skills/chaoxing-watch/scripts/bsk-daemon.sh doctor   # 先诊断：全 OK 再往下
bash $HOME/.dsh/skills/chaoxing-watch/scripts/bsk-daemon.sh          # 启动 daemon（幂等）
bsk browsers                            # ≥1 个 connected 实例，EXT 列有版本号
bsk_session start browser=<INSTANCE> noFocus=false
bsk_page navigate https://i.chaoxing.com/
bsk_inspect screenshot                  # 截到“我学的课”即就绪
```

- 哪一步 `[FAIL]` / 报 `not found` / `no browser endpoint`：按 §0.1 的矩阵处理；**缺 bsk 或扩展会先弹安装选项**（§0.1「缺组件」），修不好就**报错停止**，别在环境上反复折腾。
- 日常开课只跑 §0.1 的每会话自检即可。

### 未登录 = 报错停住（不猜不试）

判定未登录的任一现象：跳到 `passport2.chaoxing.com` / 出现账号密码框；首页没有"我学的课"只有"登录"；打开章节 URL 被弹回登录页。

命中任意一条，**立刻停止并报错**，一句话即可：

```text
学习通未登录，任务已停止。请在浏览器登录 i.chaoxing.com（登录后能看到“我学的课”）再让我继续。
```

不代输账号密码、不试验证码、不点"注册/找回密码"、不换账号登录、不靠刷新碰运气。

## 0. 环境自检（每次会话开始时跑一次，两个模块共用）

### 0.1 先 doctor，再 start（第一个动作，早于一切）

`bsk_*` 工具全靠本机 daemon 转发。**先跑只读诊断，别一上来就启动**：

```text
ops_bash: bash "$HOME/.dsh/skills/chaoxing-watch/scripts/bsk-daemon.sh" doctor
```

- 退出码 `0`（全 `[OK]`，允许 `[WARN] daemon 未运行`）→ 再启动，它幂等（已在跑 0.4s 返回）：

  ```text
  ops_bash: bash "$HOME/.dsh/skills/chaoxing-watch/scripts/bsk-daemon.sh"
  ```

  看到 `OK: daemon 已在运行 (pid …, browsers=…)` 即就绪，继续 §0.2。
- 退出码 `1`（有 `[FAIL]`）或 `3`（命名管道被拦）→ **不要硬跑 start**，按下表逐项处理；转述时**把 doctor 的 `[FAIL]` 行原样贴出来**，别只说"环境有问题"。
- `[WARN] 浏览器: 尚未接入` 不算失败：开浏览器后自然会有（§0.2）；开了仍为空，按"缺扩展"处理。

#### 自检矩阵（doctor 每行怎么处理）

| doctor 输出 | 含义 | 处理 |
| --- | --- | --- |
| `[FAIL] bsk CLI: 未找到` | 没装 bsk | 走下面「缺组件」，**先问用户再装** |
| `[FAIL] nohup: 缺失` | 环境缺 coreutils | Git Bash / macOS 自带；精简容器先装 coreutils |
| `[FAIL] daemon: 命名管道 … 被拦截` | Windows 沙箱拦了管道 | 文件策略改 `danger-full-access` 后重跑 doctor，别原地重试 |
| `[WARN] daemon: 未运行` | 正常 | 跑 start |
| `[WARN] 浏览器: 尚未接入` | 扩展没连 / 浏览器没开 | §0.2 开浏览器 → `bsk browsers`；仍空按"缺扩展"处理 |

#### 缺组件：先弹选项，再给步骤

**交互（DSH）**：用 `ask_user_question` 弹一张卡（标题 `缺少 BrowserSkill，任务无法开始`），别直接甩一段命令：

1. `给我安装步骤（推荐）` → 按下面分平台回复，等用户装完；
2. `我已经装好了，重新检测` → 重跑 doctor（最多 2 次）；
3. `先不装，停止任务` → 结束。

**非交互（Codex 等）**：直接打印同样的步骤并停止。

安装步骤（缺什么给什么）：

- **缺扩展**：Edge Add-ons / Chrome Web Store 装 BrowserSkill（同一套），图标显示 Connected 才算；说明见 <https://github.com/Tencent/BrowserSkill>；
- **缺 CLI**：同一仓库的 `install.ps1`（Windows）/ `install.sh`（macOS）；装完 `bsk --version` 要有输出，PATH 里没有就放 `~/.cargo/bin/`（macOS `~/.local/bin/`）或改 `bskPath`；
- **缺 daemon**：装完跑 `scripts/bsk-daemon.sh`；
- 用户说"装好了"→ 重跑 doctor；仍有 FAIL → 贴原文、停止，不要反复试。

为什么不能靠自动拉起：客户端默认会自己 spawn 一个 daemon（`BSK_AUTO_START`），但本宿主禁止 Job Object breakaway，自动拉起必然报 `cannot start an independent Windows daemon … os error 5`。所以脚本统一用 `bsk daemon start --foreground` + `nohup` 脱离 shell 起，并带 `--daemon-idle 2h`（默认只有 10 分钟，中途空太久会自己退出）。

- 同一个脚本管收尾：任务结束跑 `bash …/bsk-daemon.sh stop`（§5.2）；`status` 只读探测。
- 插件报 `bsk CLI ("bsk") was not found`：`bsk.exe` 复制一份到 `~/.cargo/bin/`；`bskPath` 在 profile 补丁里指向实际路径（如 `$HOME/bin/bsk.exe`），改配置要重启 profile 才生效。
- daemon 被杀过之后旧 `session` 会失联：`bsk_session list` 确认，然后重开一个。

### 0.2 再唤起浏览器（顺序第二）

```text
bsk browsers                      # 看有没有 connected 的实例
# 没有 → 打开浏览器（走用户 profile，保留登录态；必须是装了 bsk 扩展的那个）：
#   Windows: app_launch  target: C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe
#                       或 target: C:\Program Files\Google\Chrome\Application\chrome.exe
#   macOS:   ops_bash    open -a "Microsoft Edge"   或   open -a "Google Chrome"
bsk browsers                      # 5–10 秒后复查，拿到 INSTANCE
bsk_session start browser=<INSTANCE> noFocus=false   # 到前台，省得找窗口
bsk_assist resize width=1400 height=800              # 在导航之前做，不是之后
```

- `noFocus:false` **不是硬要求**：实测最小化、`noFocus:true` 起的后台窗口，都不影响学习通继续计时/播放。真正的前提只有一条——**截图要能出图**（答题模块依赖）。
- 扩展状态确认：`bsk browsers` 里 EXT 列有版本号即已连接。
- 已经在跑的浏览器不用重开；Agent Window 是独立窗口，和你自己的标签页互不干扰。

#### 0.2.1 冷启动后收掉“普通窗口”（只剩 Agent Window）

`app_launch` 冷启动浏览器会先出现一个**普通窗口**（新标签页/恢复的标签），bsk 只能在随后创建的 Agent Window 里操作。收掉普通窗口，屏幕上就只剩一个窗口，而且正是 bsk 能用的那个。

**关键：在起 session 之前先把它的 hwnd 记下来**——那时浏览器只有一个窗口，不会认错（macOS 没有 hwnd，见 §8.3）：

```text
# 1. 冷启动浏览器、等扩展连上之后，先记下唯一的那个浏览器窗口
computer_windows filter=<msedge|chrome>   # 只有 1 个：hwnd=NORMAL，标题多为“新标签页”
# 2. 起 Agent Window（这一步之后会多出第二个浏览器窗口）
bsk_session start browser=<INSTANCE> noFocus=false
bsk_assist resize width=1400 height=800
# 3. 导航到章节页，让 Agent Window 有明确标题
bsk_page navigate <章节 URL>
# 4. 关掉第 1 步记下的那个 hwnd —— 按 hwnd 精确关，不要用 alt+F4
#    Windows（任何宿主都用这条，PostMessage WM_CLOSE，不抢焦点）：
ops_bash: powershell -NoProfile -File <skill目录>/scripts/win-minimize.ps1 -Hwnd <NORMAL> -Action close
#    回读 {"found":true,"action":"close","closed":true} 才算关掉；
#    退出码 4 或 closed:false = 没关掉 —— 停下来重试，别当它已经关了
# 5. 复查：浏览器仍连接 + 只剩一个浏览器窗口
bsk browsers
computer_windows filter=<msedge|chrome>
```

- **绝对不能关 Agent Window**：它是该浏览器最后一个窗口时，关掉 → 进程退出 → 扩展断线（`browser disconnected`）→ 所有 `bsk_*` 失效。
- **别用 `alt+F4` 关普通窗口**（2026-10-28 实测翻车）：Alt+F4 关的是**当前焦点窗口**，焦点没切过去时直接把 Agent Window 关了。用 `win-minimize.ps1 -Hwnd <NORMAL> -Action close`——按 hwnd 发 `WM_CLOSE`，不需要焦点。
- **普通窗口不会自己消失**：`app_launch` 起的是独立窗口，`bsk_session start` 不会收它，`bsk_session stop` 只收 Agent Window。第 4 步没人做它就一直在地——所以要按第 5 步复查窗口数。
- 不要靠窗口尺寸认人：Agent Window 和普通窗口都可能是 2085×1191（最大化时 `resize` 的尺寸不体现），**只认第 1 步记下的 hwnd**。
- 只在"本次冷启动出来的普通窗口"上做；浏览器本来就开着（有用户自己的窗口）时**不要关任何用户窗口**，收尾 `bsk-daemon.sh stop` 即可。窗口里有用户正在用的标签时先问一句。
- 原理：扩展挂在浏览器进程上；只要还剩至少一个窗口，进程就不退。

### 0.3 红线（上一轮实际翻车点）

| 红线 | 翻车现场 | 正确做法 |
| --- | --- | --- |
| **不 stop session** | 中途 `bsk_session stop` 想"重开一个更干净的"，Agent Window 直接关闭、浏览器整个消失、bsk 工具链一起失效 | 要换参数就**再 start 一个新 session**；任务没结束绝不停 session |
| **不用 alt+F4 关普通窗口** | 焦点没切过去，Alt+F4 把 Agent Window 关了 → 进程退出、`browser disconnected` | `win-minimize.ps1 -Hwnd <NORMAL> -Action close`，回读 `closed:true` |
| **先 resize 再怀疑播放器** | 816×753 时播放器纯黑、快照里根本没有 `播放视频` 按钮，reload 一次进度归零 | 宽度 <1200 时先 `resize ≥1400×800`；播放键 99% 是被挤到下沿/被浮层盖住 |
| **不把 reload 当第一手段** | reload 之后黑屏照旧，唯一效果是播放进度 0:00 | 顺序：resize → 清遮挡 → 等 5s → 再 reload |
| **播放中点击要先重取 ref** | 控制条 3 秒自动隐藏，旧 ref 点到已隐藏节点，白跑一轮 | 每轮快照 → 点击连做；点不动就重取 ref |

## 1. 课程模块·进入课程（一律从 i.chaoxing.com 起）

**入口固定 `https://i.chaoxing.com/`；课程不写死，用户说哪门就找哪门。**
**进门先验登录**：被跳到登录页 / 看不到"我学的课"，按"前置·未登录"**直接报错停止**。

```text
bsk_page navigate https://i.chaoxing.com/
bsk_assist resize width=1400 height=800
bsk_inspect screenshot            # 看“我学的课”卡片墙
```

### 1.1 截图认课（不依赖课程 id）

1. 先把"我学的课"滚到顶部，再截一张整屏。
2. 按**标题文字**找用户说的课，允许简写：说"高数"就匹配"高等数学A(1)"，说"大英"就匹配"大学英语（一）"。
3. 命中后：
   - 快照能列出 `link "课程名"` 时直接 `click` 它；
   - 只能看图时，点**卡片标题文字**——不是卡片右上角菜单，更不是左侧"考试列表/超星课表"。
4. 卡片没露出来就滚一屏**重新截**，别凭记忆点位置。

**多门同名 / 多个班**：先列出候选（课程名 + 开课时间 + 班级/教师），问一句"同名课有多门，选哪个？"，等用户指定；只有**唯一匹配**或用户已明确指定时才继续。

不得按"开课时间最新"自行选择——选错课会把视频进度记到另一门课上，事后删不掉，自动化再稳也没有意义。用户已经说清是哪门（含班级/教师）时不要再问。

### 1.2 目录里认节（已完成的一律跳过）

**先看对号：绿色 `✓` = 已完成，直接跳过，不点、不进、不重刷。**

进课程后右侧是章节目录，按用户的话定位：

- 给了节号（如 `1.1`）→ 找 `1.1`；若已是 ✓，说一句"该节已完成，跳过"（用户说的是"全部"就直接做下一个），否则问下一节；
- 只给标题关键词 → 按关键词匹配，同样先看是否 ✓；匹配到多节 → 列出来问，别猜；
- 用户说"这门课 / 全部 / 剩下的"→ **从上往下找第一个橙色数字的节**；
- 什么都没给 → **问一句"做哪一节？"**（可列 3–5 个橙色数字节），等回答再动；
- 用户明确说"重刷/再看一遍"才碰 ✓ 的节。

```text
bsk_inspect observe      # 目录里找 “1.1 …”，看行尾是 ✓ 还是橙色数字
# 不在视口 → 滚目录后再找，或截一张看位置
```

**橙色数字的含义**：该节还剩几个任务点（视频 1 + 测验 1 = 2）。**课程模块只做视频那一个**：做完视频数字从 `2` 变 `1`，页面出现 `任务点已完成` 即本节播放完成；剩下的测验任务点由**答题模块**（§4）独立处理。

### 1.3 顺序推进：默认做完一节就停

```text
取目标节 → 后台播放（§3）→ 读“任务点已完成”
  ├─ 已完成 → 输出“<节名> 已播放完” → 停住（用户说连续才接着做）
  └─ 未完成 → 回播放循环，别跳走
```

- **默认做完一节就停**：不自动跳下一节、不自动切模块、不自动开始答题。
- 用户说"继续/下一节/全部/连着播"→ 从该节的下一个橙色数字节接着做，不要从头再扫；
- 只清视频任务点；测验任务点保持原样；
- 已经完成的节不复查、不点开、不截图确认。

进"章节详情"后有两个 tab：`1 视频` / `2 章节测验`。**课程模块只点"视频"**。
播放器在两层 iframe 里，`observe` 看不到按钮，改用快照（会展开 iframe）拿 `button "播放视频"` 的 ref。

### 1.4 记 URL，后续节直接跳

章节页 URL 形如
`https://mooc1.chaoxing.com/mycourse/studentstudy?chapterId=<章节id>&courseId=<课程id>&clazzid=<班级id>&enc=<enc>`

- 第一次进节后把 `courseId / clazzid / enc` 记下来；
- 后续每一节只换 `chapterId` 再 `navigate`，省掉"课程 → 目录"两跳；
- **换课程必须重走 §1.1**，不要复用上一门课的 id；
- 答题模块用同一套 URL 规则，但不复用播放模块的窗口状态；
- **章节以 URL 里的 `chapterId` 为准**：从目录点进去的节不会错，标题上的节号只作显示。若 `chapterId` 和目录项对不上 → 停止并报告，不要靠题干猜。

## 2. 课程模块·起播前：清遮挡 → 时长 → 2 倍速

**顺序不能反**：浮层盖住的是播放器右下角，而倍速控件正好在那儿。

1. **先清遮挡**（见下表）。弹着"可边看边记…"就先点 **知道了**；右侧"Hi，XX：本课开放学习的 N 个任务点…"卡片点右上角 **×**。
2. **读时长**：截图一次，记 `当前/总时长`（如 `0:24 / 11:49`）。后续算进度只认这个总时长。
3. **设 2 倍速**：快照找 `button "播放速度 [has-submenu]"` → 展开菜单 → 点 `menuitemradio "2x"`。**必须回读两处**：菜单里 `2x` 变 `[checked]`、控制条文字变 `2x`。实测默认可能是 `0.75x`，不核对就会以为设成功了。只有 1.5x 时用 1.5x 并在汇报里注明。
4. 倍速控件被挡住时，先 `resize` 放大（≥1400×800）再点。
5. **静音**：快照找控制条上的 `button "静音"` → 点，回读为已静音。
6. 起播键是**视频正中央的大圆钮**（`button "播放视频"`），不是底部控制条那个小三角——小三角最容易被浮层压住。
7. 起播之后按 §3.1 最小化窗口、后台播放。

### 遮挡清单（谁盖住了播放器）

| 遮挡物 | 位置 | 处理 |
| --- | --- | --- |
| 笔记提示"可边看边记…" | 播放器右下角 | 点 **知道了**（点一次；没出去就重取 ref 补一次） |
| "Hi，XX：N 个任务点…" | 右侧目录区中下 | 点卡片右上角 **×**；也可能自己超时消失，别反复点 |
| 学习通吉祥物气泡 | 右下角 | 会挡住倍速下拉，先 `resize` 放大 |
| "Agent 正在控制"条 | 窗口底部居中 | 不挡播放键；但**窗口缩小时会顶到播放器下沿** |

**窗口尺寸红线**：Agent Window 默认约 1584×723，播放器宽约 1000px。宽度低于约 1200px 时，播放键会被下沿工具栏/气泡挤到遮挡区——**不要硬点，先 `resize` 到 1400×800 以上**。缩窗口只影响我们自己看，不影响已开始的播放。

> 这张清单同样适用于答题模块：测验页的浮层挡住选项或"提交"时，先清再点。

## 3. 课程模块·后台播放

**目标：让视频在后台自己走满，期间不占屏幕、不答题。** 一节的标准动作：

> 只处理**视频**任务点。遇到阅读、文档、PPT、讨论这类非视频节：不点、不猜，记一句"非视频任务点，跳过"，再做下一个橙色数字节。

### 3.1 起播并最小化

```text
# 1) 浏览器/session 见 §0.2；已按 §1.4 导航到章节页（还没到就先 navigate）
bsk_page navigate <章节 URL>
# 2) 关掉冷启动的普通浏览器窗口（§0.2.1）
# 3) 播放准备：2x + 静音，两样都要回读确认（§2）
# 4) 起播，并读起点与总时长
快照 → button "播放视频" → 点
bsk evaluate 一次读齐 {currentTime, duration, paused, playbackRate}
# 5) 确认在播后再最小化：先取标题栏“最小化”按钮的 ref，再 invoke
#    （实测：只给 hwnd + action=minimize 会报 BAD_REQUEST，必须带 ref）
computer_ui hwnd=<AgentWindow> filter=最小化
computer_ui_action action=invoke ref=<“最小化”按钮的 ref>
#    任意 CLI：scripts/win-minimize.ps1 -Title "<document.title>" -Action minimize（回读 iconic:true）
#    先查状态用 -Action status：只读，输出 {"found":true,"iconic":...}，不动窗口
#    标题匹配到多个窗口时脚本直接报错退出（exit 3，什么都不做）—— 此时缩小 -Title，别猜
#    macOS：osascript 最小化（§8.2）
```

- 起播后必须回读 `paused === false` 且 `playbackRate === 2`，否则补点播放/重设倍速再继续。
- 最小化之后读状态一律用 `bsk evaluate`（课程模块不需要截图）。
- 起播后可以提醒一句：**"最小化、切到别的程序、熄屏一般都不影响播放（实测 Windows 11 + Edge）；别关这个窗口、别退出浏览器就行。"** 其它浏览器版本可能后台节流，所以播放循环始终复查 `paused`。

### 3.2 轮询节奏（按倍速算）

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
   ├─ t/dur ≥ 0.97 → 进入结束判定（§3.3）
   └─ 否则 → sleep（按上表）→ 下一轮
```

- daemon 的 `--daemon-idle 2h` / `--session-idle 2h` 在正常轮询（≤110s 一次）下不会触发；中途空等超过 2 小时 daemon 会自己退出，恢复时按 §0.1 重新拉起。

### 3.3 完成判定：只看“任务点已完成”

| 状态 | 含义 |
| --- | --- |
| `option "任务点未完成"` / 目录橙色 `2`、`1` | 还没看完，继续播 |
| **`option "任务点已完成"`** | 本节播放任务完成（目录 ✓ 可交叉确认） |

- 页面出现 `option "任务点已完成"` 即视为该节**视频任务点完成**；目录里橙色数字消失或变 ✓ 作为交叉确认；
- 读法：`bsk evaluate` 读播放器状态与任务点文案，不用为看一眼去截图；
- 进度 ≥90% 只是必要条件，**"任务点已完成"才是通过条件**；
- 完成后立刻收手：**不点章节测验、不读分**——答题是 §4 的独立模块；
- 进度回 0:00 / 切 tab 重载属正常，点播放会从服务端进度续播。

### 3.4 暂停 / 睡眠后自愈（“点了继续”不等于恢复）

恢复靠轮询补点，但播放器可能点了继续、下一轮又停——**判据不是 `paused:false`，是进度有没有前进**：

| 现象 | 判据 | 处理 |
| --- | --- | --- |
| 读到 `paused:true` | 单轮 | 快照 → 点播放 → 下一轮复查 `t` |
| 点完 `paused:false` 但 `t` 不涨 | 连续 2 轮（间隔 10s） | **假恢复**：`restore` 到前台 → 等 5s → 连读两次 `t` 确认在走 → 再最小化 |
| restore 后仍不走 | 连续 2 轮 | reload 章节页（回到 0:00，点播放按服务端进度续播）→ 重设 2x + 静音 + 起播 |
| 30 分钟内 ≥3 次暂停 | 累计 | 先保持前台观察一轮（排除遮挡/播放器问题）；仍频繁就按 §6 查播放器，汇报时注明 |

**熄屏 / 锁屏 / 短时睡眠通常不用管，醒来复查一次就行**（Windows 11 + Edge 实测熄屏后照常推进；其它浏览器版本可能后台节流，按上表复查；**真睡眠未实测**，同样按下面的表处理）：

| 醒来后读到 | 处理 |
| --- | --- |
| `t` 在涨、`paused:false` | 什么都不做，继续轮询 |
| `paused:true`，或 `t` 连续 2 轮不动 | 补点播放，再按上表判"假恢复" |
| `ensure daemon is running` / `no endpoint` | daemon 掉了：`scripts/bsk-daemon.sh` 重起 → 重开 session → 重导航章节 URL |

- 例外是**长时间睡眠 + 断网**：daemon 的 `--daemon-idle 2h` 可能到期、session 可能失效，按上表第三行处理；
- 想更稳可以课前关睡眠（`powercfg /change standby-timeout-ac 0`、`caffeinate -dimsu &`），**但这不是前置条件**；
- 发生过"假恢复"升级时，汇报按 §5.1 补一句 `异常：播放中暂停 N 次，restore 后恢复`。

## 4. 答题模块·章节测验（截图读题）

> **独立模块。** 与课程模块（§1–§3）互不调用：播放模块不点测验，本模块不碰播放器。
> **读题只靠截图**；最小化也能答题（实测截图正常），不用为了答题还原窗口。
> **题型不限于选择/判断**：单选、多选、判断、填空、简答（含名词解释、论述）都要做，答案由模型按学科常识自己给，不查资料。

### 4.0 开跑前：问一句“是否直接提交”

动第一道题之前先确认提交方式，**整轮不变**：

| 环境 | 做法 |
| --- | --- |
| 交互（DSH 对话等） | 直接问用户：**“答完直接提交，还是先给你看答案？”** 等回答再开始；用户说"直接交/别问了"就按直接提交走 |
| 非交互（`codex exec` 等无法回话） | **默认不提交**：填完、截图、停住，等用户下一条指令说"提交"；除非任务里已明确写"直接提交" |

- 用户选「先看」→ 走 §4.7 的"先确认后提交"分支；
- 用户选「直接提交」→ 走 §4.7 的"直接提交"分支；
- 中途不许改主意、不许两种混用。

### 4.1 窗口就位

```text
# 0) daemon / 浏览器 / session 见 §0.1–§0.2；从播放模块切过来时窗口多半是最小化的
#    —— 最小化也能答题，下面 restore 只是“想看着它答”时可选做的
computer_windows filter=<msedge|chrome>           # 拿到 Agent Window 的 hwnd
computer_ui hwnd=<AgentWindow>                    # 读窗口节点
computer_ui_action action=restore ref=<Window 节点 ref>   # 可选（只给 hwnd 会报 BAD_REQUEST）
computer_windows focus_hwnd=<AgentWindow>
#    任意 CLI：scripts/win-minimize.ps1 -Title "<document.title>" -Action restore
#    还原前可先 -Action status 确认窗口还在、当前是否 iconic
#    macOS：osascript 还原 + activate（§8.2）
bsk_assist resize width=1400 height=800           # 必做：宽度 <1200 选项会被挤走（最小化时也照做）
bsk_page navigate <章节 URL>
bsk_inspect screenshot                            # 能出图（<5s）即就绪，最小化下也应能出图
```

- **最小化不影响答题**：实测最小化下截图、点选、提交都正常，不用为了答题把窗口还原。唯一要守的是宽度 ≥1200。
- 保持 1400×800，答题过程中别再动窗口。
- 出不了图 → 按 §6"答题截图超时"处理（先 restore + resize 再截，仍不行就是 session 掉了）。

### 4.2 进入测验

- 用户给了节号/标题 → 直接 `navigate` 该节 URL（只换 `chapterId`，同门课复用 `courseId/clazzid/enc`，§1.4）；
- 用户说"全部 / 剩下的"→ 目录里从上往下找还有测验待做的节（视频已完成时通常剩 `1`；数字 `2` = 视频也没做，**仍可先答**）；
- 什么都没给 → 问"做哪一节的测验？"，别自己挑；
- **先看状态再动手**：点进 `2 章节测验` 后，标题旁已显示 `已完成` / `本次成绩` → **直接退出，不重做**，说一句后问下一节。

```text
bsk_inspect screenshot        # 确认 tab 与页面位置
bsk_inspect snapshot          # 取页面顶部 button "章节测验" 的 ref
→ click
bsk_inspect screenshot        # 确认已进测验页 + 标题状态（已完成就退出）
```

- **点一次没切过去是常见现象**（iframe 还没就绪）：重取 ref 再点一次；不要因此 reload。
- 测验页标题里的节号可能和目录编号不一致（目录 `4.1`、测验页 `16.1`）：**以 URL 的 `chapterId` 为准**（§1.4），标题只作显示；对不上就停下报告，别靠题干猜。
- **有的课程没有 `2 章节测验` tab**（测验放在「作业」或「考试」里）：不属于本模块，报告"本节无章节测验，跳过"，不要去作业/考试页乱点。

### 4.3 读题：只靠截图

1. 整屏截一张，先数题、认题型：**单选 / 多选 / 判断 / 填空 / 简答（含名词解释、论述）**。
2. **题干、选项、空格都只从截图读**；页面文本被混淆，读不出原文，不要试图从文本里拼题。
3. 一屏放不下就下滚再截：`bsk_interact wheel deltaY=400`；**只往下滚，别来回滚**（回滚会重排，ref 失效）。
4. 题干长/字小看不清时裁剪截图：`bsk_inspect screenshot ref=<题目容器>`。
5. 截图糊/被浮层挡 → 先复截，再按 §2 遮挡清单清（知道了 / ×）；仍不行才 reload 章节页——**reload 会丢已选答案，只在尚未作答时用**。

### 4.4 作答之一：选择 / 判断（ref 点击）

1. 快照一次拿到整页 `radio` / `checkbox` 的 ref（**不用滚动也能点**，ref 是全页的）。
2. 选项按钮的名字形如 `radio "A … 选择"`，**用字母 A/B/C/D 定位**；判断题是 `对选择` / `错选择`。哪个字母对应哪段文字，仍以截图为准。
3. 单选/判断：点对应 ref；**点完立刻截图确认圆圈变蓝**。
4. 多选：逐个点每个 `checkbox`，全部点完再截一张核对（漏点一项就是错题）。
5. 点不动 / 不变蓝：**重取 ref 再点**；仍不蓝就点该选项的 label 文本 ref。

### 4.5 作答之二：填空 / 简答（文本输入）

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
   - 不编造出处、不写"根据教材/如上所述"这类套话。

### 4.6 通用答题纪律：简单思考，不纠结

每题先判三态：**ANSWERED**（能定）→ 直接答；**UNCERTAIN**（拿不准）→ 给最主流、最保守的答案并记数；**UNREADABLE**（读不出）→ 先重截/裁剪，仍不行按 §6 排查，**不许猜**。

1. **简单思考**：能一眼定的直接定；需要推的做一两步推理或排除，再落答案。
2. **不深挖**：不翻书、不查网、不大段分析、不反复推敲；同一题不改第二遍。
3. **不留空、不写"不会"**；UNCERTAIN 的题在汇报里附数量（§4.8）。
4. 填完扫一眼：**有没有漏题、有没有把答案填错框**——只查这两样，不逐题复查对错。

### 4.7 提交：先看模式 / 直接模式

**A. 先确认后提交**（用户选了「先看」，或非交互环境默认）

1. 全部填完后 `bsk_inspect screenshot` 截一张，能看清题与已填内容；
2. 停下，向用户说明：**"已填完，共 N 题，确认提交？"**（非交互环境就到这里等指令）；
3. 用户说"交"→ 转 B；用户要改 → 只改他指出的题，然后重新截图确认。

**B. 直接提交**

1. 点页面底部 `button "提交"` → 弹出 `alertdialog "提示"` / `确认提交？`。
2. **重新快照**取弹窗内的按钮再点——**绝不能复用页面那个"提交"的 ref**（会点到背景按钮上）。注意：弹窗按钮**屏幕上是「提交」、快照里叫「确定」**，按后者取 ref。
3. 回读两个信号：**弹窗消失** + 标题变成 `已完成`（目录里该节随即可见 ✓）；两个都有才算提交成功。
4. 信号不全时按分支走，**不要直接再点页面"提交"**：
   - 弹窗仍在 → 重取弹窗内 ref 点一次（可能只是没点上）；
   - 弹窗已消失、标题未变 → reload 章节页**只读确认**（不重答、不再提交）；
   - reload 后仍不明确 → 报"提交状态无法确认，请人工核对"，停止，不重试。

**交完就走**：不读分、不核对正确率、不复盘题目、不切回视频 tab（切回会让播放器重载回 0:00）。

### 4.8 汇报：一行，不读分

```text
1.1 课程导论 测验已提交                  # 两个信号都确认
1.1 课程导论 已填完 4 题，待确认提交      # 先看模式还没交
1.1 课程导论 提交状态无法确认，请人工核对  # 信号不全且只读确认也失败
```

- 有拿不准的题就附在后面：`1.1 课程导论 测验已提交（4 题，其中 1 题不确定）`；
- 只输出这一行，不贴截图、不 `present`、不报分数/正确率/正确题数；
- 停住/连做的规则同 §5.1；全部答完按 §5.2 收尾。

## 5. 汇报与收尾

### 5.1 汇报（两个模块各一句）

```text
1.1 课程导论 已播放完      # 课程模块
1.1 课程导论 测验已提交    # 答题模块
```

- **不出截图、不 `present`、不报分数/正确率/正确题数**；完成就是唯一交付物；
- 多节按行输出，一行一节；
- 各自播完/答完**停住等用户决定是否下一节**：不自动答题、不自动跳下一节、不自动切模块；
- 只有出异常时才多写一句（`异常：xxx，已用 xxx 处理`）。

### 5.2 收尾：任务结束再关 daemon

最后一行汇报发完、确认本任务**没有待做的节**之后，**先按 §5.3 删除运行缓存**，再关 daemon：

```text
ops_bash: bash "$HOME/.dsh/skills/chaoxing-watch/scripts/bsk-daemon.sh" stop
```

- 关的是**整机 bsk daemon**：所有 Agent Window 与浏览器 session 一起释放，浏览器本身不退出；下次跑 §0.1 重新拉起（约 1–2s）。
- 脚本自带守卫：**活动 session 多于 1 个时拒绝停止**（打印 `SKIP:`），避免把另一个任务的窗口一起收掉；确认要关用 `stop --force`。看到 `SKIP` 就不要重试，说明还有别的会话在用。
- **只在任务真的结束时调**：中途停会让下一个 `bsk_*` 调用报 `no endpoint`。
- 用户说"等会儿继续""先别关"，或明显还要刷/答下一节 → **不关**。
- 不要指望空闲自动退出：扩展连着时 daemon 能挂几十分钟不退，所以"结束就关"只能靠显式 `stop`。

### 5.3 临时文件：跑完自己删（不留截图）

**从第一步起就固定用一个运行缓存目录**，所有截图、快照、临时 JSON 全写进去，**不要写进项目/仓库**：

```bash
CACHE_DIR="$(bash "$HOME/.dsh/skills/chaoxing-watch/scripts/cache.sh" init)"   # 建 0700 目录，顺手清扫 2 天前的旧缓存
# 之后所有 screenshot --out、快照重定向、临时文件都放 "$CACHE_DIR/"
```

**收尾（和 §5.2 同一时刻）必须删，且要回读确认：**

```bash
bash "$HOME/.dsh/skills/chaoxing-watch/scripts/cache.sh" clean "$CACHE_DIR"    # 删除并校验不在了
```

- Windows Git Bash 的 `/tmp` 就是 `%TEMP%`，macOS 的 `$TMPDIR` 同理：都不在仓库里，不会污染 `git status`；目录建出来是 `0700`，本身只有当前用户可访问。
- 用户明确要"留证据 / 给我看截图"时，只把**指定的那一张**另存到用户指定位置，其余照删。
- 正常结束、报错中止、用户说"先不刷了"都要删；只有用户明确说"截图留着"才不删。
- 只删自己建的缓存目录：`clean` 会拒绝路径不合规的目录；不确定就先 `cache.sh status` 看它管理哪些。
- 截图里有课程名、姓名、题目，别往外挪；跑完 `git status` 应保持干净。

## 6. 故障恢复（两个模块共用）

| 现象 | 处理 |
| --- | --- |
| `session not registered` | daemon 重启过；`bsk_session list` → 重开 session → **再导航一次章节 URL**（别重新走课程列表） |
| `ensure daemon is running` / `no browser endpoint` / 工具全挂 | daemon 掉了：跑 `scripts/bsk-daemon.sh`（§0.1）→ `bsk status` 复查 → 重开 session |
| 没有 connected 的浏览器 | `bsk browsers` 为空 → `app_launch` 起 Edge/Chrome → 等 5–10 秒复查 → 再 start session |
| **bsk 工具没反应/报错，但 `bsk status` 正常** | **先开浏览器**（`app_launch` 指到 `msedge.exe` 或 `chrome.exe`），别先重启 daemon：浏览器一退出，Agent Window 跟着没，daemon 日志会写 `session removed: user closed Agent Window` + 紧接着 `browser disconnected`；扩展 5–10s 重连后重试原命令 |
| Agent Window 自己消失 | 先看 `~/.bsk/daemon.log.<日期>`：`idle session stopped` = `--session-idle` 到期（默认 5 分钟，脚本已改成 2h）；`user closed Agent Window` = 窗口被外部关掉 |
| 命名管道 `拒绝访问 (os error 5)` | 会话文件策略不是 `danger-full-access`——沙箱拦了 `\\.\pipe\bsk-daemon-*`；改策略后重跑（**Windows 专属**） |
| macOS：osascript 窗口动作无效 / 提示无权限 | 见 §8.5：给运行 DSH 的终端开"辅助功能"；`miniaturized` 不生效就退化为不最小化 |
| 播放器纯黑 / 没有 `播放视频` 按钮 | 先 `resize ≥1400×800`；再清浮层；等 5s 重截；都不行才 reload |
| 视频自己停住（读到 `paused`） | 偶发；`bsk evaluate` 读到 `paused` 就补点一次播放。连续两轮不走按 §3.4 判"假恢复" |
| ref 失效 / 点不中 | 重新快照取 ref，别复用上一轮；控制条隐藏时更必须重取 |
| 进度回 0:00 / 切 tab 后从 0 开始 | 播放器重载，属正常；点播放会按服务端进度续播，不用重刷整节 |
| 倍速点不到 / 默认不是 2x | 先 resize + 清遮挡再点；**点完必须回读** `menuitemradio "2x" [checked]` + 控制条 `2x` |
| 目录没显示 ✓（其实已完成） | 目录刷新滞后：reload 一次章节页再读；以快照里的 `2.3 已完成` 为准 |
| **答题截图 30s 超时** | 截图通道断了（最小化本身不是原因，实测最小化下图正常）：`computer_ui` 取窗口节点 → `action=restore ref=<窗口>` → `resize 1400×800` 再截；仍超时说明 session 掉了，重开 session 重导航 |
| 选项点了不变蓝 | 重取 ref（别复用）；仍不蓝就点该选项的 label 文本 ref；不行再清浮层 |
| 提交后弹窗不关 / 标题仍"未完成" | 先看弹窗在不在：在 → 重取弹窗内 ref（屏幕 `提交`、快照 `确定`）再点一次；已消失但标题没变 → reload 章节页只读确认，**不重答、不重复提交**；仍不明确 → 报"提交状态无法确认" |
| 截图太占 token | 用 `bsk_inspect screenshot ref=<播放器/题区/目录>` 裁剪；整屏只在认课/认页时用 |

## 7. 禁止

### 通用

- **浏览器页面交互只用 bsk**：起不来按 §6 修，修不好**报错停止**。窗口/进程/daemon 只能用本文列出的 `computer_*`、`app_launch`、`ops_bash`、`osascript` 和 `scripts/`；**不得引入 Playwright / Selenium / puppeteer / 直连 CDP 等第二条浏览器通道**。
- **只用装好 bsk 扩展的 Edge 或 Chrome**，选定后本任务固定用它；不许临时换浏览器、不许用没装扩展的浏览器。
- 被遮挡就先放大窗口、清浮层，再点；**不许硬点被盖住的位置**。
- **任务没结束不许 `bsk_session stop`**；要换参数就再开一个新 session。
- 没有页面证据，不许声称"播放完 / 任务点已完成 / 测验已提交"。

### 课程模块

- 不许拖进度条、不许跳着看。
- **不许点"章节测验"、不许提交答案、不许读分**——答题是 §4 的独立模块。
- **不许重刷已完成的节**：✓ 的节不点开、不进、不截图确认（用户明确说"重刷"除外）。
- 视频任务点仍"未完成"时不许跳到下一节。

### 答题模块

- **没有截图就不许答题**：一旦出不了图，先按 §6 排查，别凭记忆或推测作答。
- **题干与选项只从截图读**，不许猜题、不许对乱字做"合理推测"、"读不出"就是停下来。
- **开跑前必须问"是否直接提交"**；用户选「先看」或无法回话时，**未经确认不许点提交**。
- **不许留空题**：填空、简答也要答，答案由模型按学科常识给，不查资料、不编出处。
- 交完就走：**不读分、不报正确率、不复盘题目**，不许切回视频 tab"确认一下"。
- 已作答的测验页不许 reload（提交后的只读确认除外，§4.7）。

## 8. macOS 分支（Windows 流程不变）

> 只有"开浏览器、窗口最小化/还原/关闭"这三类动作与 Windows 不同；`bsk_session`、`bsk_page`、截图、快照、`evaluate`、轮询节奏全部照用。
> 前提：macOS 13+、**装了 bsk 扩展的 Edge 或 Chrome**、`bsk` 在 PATH（`install.sh` 默认 `~/.local/bin`）。

### 8.1 起浏览器

```text
# 二选一，选装了扩展的那个
ops_bash: open -a "Microsoft Edge"
ops_bash: open -a "Google Chrome"
# 都不行就用完整路径：open -a "/Applications/Microsoft Edge.app" / open -a "/Applications/Google Chrome.app"
bsk browsers                              # 5–10 秒后复查，EXT 列有版本号
```

### 8.2 最小化 / 还原（替代 `computer_*` 窗口动作）

先定这次用哪个浏览器（要和 `bsk browsers` 里连上的那个一致），后面所有窗口动作都指向同一个应用：

```bash
APP="Microsoft Edge"      # 或 APP="Google Chrome"

# 看窗口标题，确认哪个是 Agent Window
osascript -e "tell application \"$APP\" to get name of windows"

# 最小化（课程模块起播后）
osascript -e "tell application \"$APP\" to set miniaturized of window 1 to true"
osascript -e "tell application \"$APP\" to get miniaturized of window 1"    # 回读 true

# 还原 + 置前（答题模块 §4.1）
osascript -e "tell application \"$APP\" to set miniaturized of window 1 to false"
osascript -e "tell application \"$APP\" to activate"
```

- `window 1` 不一定是 Agent Window。分不清就先 `bsk_page navigate` 到章节页，让 Agent Window 有明确标题，再按标题定位：

  ```bash
  osascript -e "tell application \"$APP\" to set miniaturized of (first window whose name contains \"章节\") to true"
  ```

- **回读是硬要求**：`miniaturized` 为 `true` 才算最小化成功；没生效就按 8.2.1 退化。
- 最小化后读状态用 `bsk evaluate`；答题模块若出不了图，再还原窗口重截。

#### 8.2.1 退化（`miniaturized` 不生效时）

不最小化也没关系：**保持前台、让窗口被别的窗口盖住**即可（实测遮挡和最小化都不影响播放）。若仍读到 `paused`，按 §3.4 补点一次播放；汇报时可注明"macOS 未最小化"。

### 8.3 冷启动的普通窗口（可选）

macOS 没有 hwnd，`computer_windows` 用不了：

- **默认不关**：bsk 只操作 Agent Window，普通窗口留着不影响功能；
- 要关就按标题、别按序号，而且**绝不能关 Agent Window**（它若是最后一个窗口，关掉 = 进程退出 = 扩展断线）：

  ```bash
  osascript -e "tell application \"$APP\" to close (every window whose name is \"新标签页\")"
  ```

### 8.4 路径与平台差异

| 项 | Windows | macOS |
| --- | --- | --- |
| 浏览器 | Edge `...\msedge.exe`；Chrome `...\chrome.exe` | `open -a "Microsoft Edge"` / `open -a "Google Chrome"` |
| bsk 位置 | `~/.cargo/bin/bsk.exe` | `~/.local/bin/bsk`（install.sh 默认） |
| 窗口动作 | `computer_windows` / `computer_ui_action` | `osascript`（§8.2） |
| 沙箱 | 必须 `danger-full-access`（命名管道） | 无此问题，可忽略 |
| daemon 脚本 | 照跑 | 照跑（bash，自带 3.2 够用） |
| 日志 | `~/.bsk/daemon.log.<日期>` | 同 |

### 8.5 macOS 已知坑

| 现象 | 处理 |
| --- | --- |
| osascript 提示不允许控制 / 无权限 | 系统设置 → 隐私与安全性 → 辅助功能，给运行 DSH 的终端（或 DSH 本体）授权后重试 |
| `miniaturized` 报错或回读 false | 浏览器版本对 AppleScript 支持不同；走 8.2.1 退化，不要反复重试 |
| `open -a` 失败 | 用完整路径 `.app`；确认装的是 Edge 或 Chrome，且扩展在里面 |
| 截图 30s 超时 | 先 restore + resize 再截（§8.2）；macOS 最小化下能否截图未实测，超时就当异常排查 |
| Safari / Firefox | 不支持；只认装了 bsk 扩展的 Edge 或 Chrome |

## 9. 任意 CLI（Codex 等）

> 正文是 DSH 写法；换 CLI 只看「跑法」那张表。本节只记 Codex 特有的坑（实测 codex-cli 0.164.0）。

### 9.1 安装

```text
npm i -g @openai/codex          # 得到 codex 命令
codex --version
```

- 技能目录：`~/.agents/skills/`（把本目录整个拷进去即可）；
- 通用浏览器技能可另装：`bsk install-skill --harness codex`（或 `--all`）；
- 本机的 bsk 若不在 PATH：`export PATH="$HOME/.local/bin:$PATH"`。

### 9.2 沙箱（必须放开）

`codex exec` 默认 `-s read-only`，bsk 会先报 `could not determine user home directory`；只设 `BSK_HOME=%USERPROFILE%\.bsk` 只能解决第一层，接着会撞命名管道 `拒绝访问 (os error 5)`。

**跑刷课任务必须：**

```text
codex exec -s danger-full-access --skip-git-repo-check - < prompt.txt
```

### 9.3 窗口

- Codex 没有 `computer_*`，`bsk window` 也只有 `resize`；
- 最小化 / 还原用 `scripts/win-minimize.ps1`（Windows）或 `osascript`（macOS），见「跑法」表；
- 脚本靠页面标题定位窗口，标题用 `bsk evaluate --session <sid> "document.title"` 取。

### 9.4 提交确认在 Codex 里怎么落

`codex exec` 是**非交互**的，用户不能在跑到一半时回话，所以按 §4.0 走默认分支：

- 默认：**答题只填不交**，最后一行报 `已填完 N 题，待确认提交`；
- 要自动交，就在 prompt 里显式写"答题部分直接提交"，别指望它自己猜。

### 9.5 实测（2026-10）

一节「任意课程」的章节：课程模块 2 倍速播放 30 秒（`paused=false`、`rate=2`），答题模块 3 题按截图作答并提交成功，全程约 12 万 token。截图直接由 Codex 读取，无需额外 OCR。

## 10. 维护：装在多处时怎么对齐

装一份就能用（放哪个目录见 README「装到哪个目录」）。同一个 skill 如果在多个目录各放了一份，用仓库里的 `scripts/sync-copies.sh` 对齐：

```bash
bash scripts/sync-copies.sh status              # 只比对：一致=0，有差异=3
bash scripts/sync-copies.sh diff                # 逐文件看差异
bash scripts/sync-copies.sh --dry-run           # 预演，不写文件
bash scripts/sync-copies.sh --source <源目录>    # 指定源（默认取 ~/.dsh/skills/chaoxing-watch）
```

- 同步清单是 `SKILL.md` + `scripts/` 下所有脚本（`sync-copies.sh` 自身除外，自动发现，加新脚本不用改清单）；
- 逐文件**先比对再决定**：内容相同就 skip，绝不做无条件覆盖；要覆盖的旧版本会先备份到 `~/.chaoxing-watch-sync-backup/<时间戳>/`；
- README、LICENSE、.gitignore 只留在仓库，不进技能目录。
- ⚠️ 同步会替换磁盘上的文件，**正在跑的会话不会热更新**：它已加载的 SKILL.md 正文仍是旧的，而脚本是按路径执行的新版。所以别在一节课跑到一半时同步；改脚本请保持旧参数可用（向后兼容），否则旧正文会去调用新脚本。
