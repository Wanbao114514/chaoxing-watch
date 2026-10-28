# chaoxing-watch

在学习通（超星）网页版按章节推进课程的小技能。**为 DeepSeek Harness 编写并优化**：窗口最小化/还原、截图、播放器与任务点状态回读都有原生工具，轮次少、成本低。Codex 或任何能跑 shell 的 CLI 也能用，只是要自己拼脚本，**成本会明显更高**（见[成本参考](#成本参考)）。

大学里有不少课程以视频时长和章节练习计分：这个 skill 把"看完 / 点完"这类重复操作交给自动化，把时间留给真正要学的课。**考试、人脸识别与验证码不介入，学习记录按平台实际生成**——进度是真播完的，答案由你确认后再提交。

两个模块，互不调用：**视频任务点**（2 倍速 + 静音，最小化后台播完）、**章节测验**（截图读题、模型作答、提交前先问）。一次只跑一个。

| 模块 | 做什么 | 怎么算成功 |
| --- | --- | --- |
| 课程 | 截图认课 → 目录挑未完成的节 → 2 倍速 + 静音 → 最小化后台播 | 页面出现 `任务点已完成` |
| 答题 | 进章节测验 → 截图读题 → 点选 / 填空 → 提交前问一句 | 提交弹窗消失 + 标题显示 `已完成` |

流程细节、判据、禁令都在 [SKILL.md](SKILL.md)。

---

## 前置

Windows 10/11（需 Git Bash）或 macOS 13+；装了 [BrowserSkill](https://github.com/Tencent/BrowserSkill) 扩展的 **Edge 或 Chrome**；`bsk` CLI 在 PATH 里（`bsk status` 能通）；学习通**已登录、已选课**。

Windows 上 DSH / Codex 的文件策略要设成 `danger-full-access`——`workspace-write` 会拦 `bsk` 的命名管道，工具全挂。macOS 需给运行 agent 的终端授「辅助功能」。

---

## 安装

<details open>
<summary><b>DeepSeek Harness</b>（推荐）</summary>

```bash
git clone https://github.com/Wanbao114514/chaoxing-watch.git /tmp/chaoxing-watch
mkdir -p ~/.dsh/skills/chaoxing-watch
cp -r /tmp/chaoxing-watch/. ~/.dsh/skills/chaoxing-watch/
```

重开会话，技能列表里出现 `chaoxing-watch` 即可。日常推荐 DSH：窗口最小化 / 还原、截图、播放器与任务点状态回读都有原生工具，不用自己拼命令。

</details>

<details>
<summary><b>Codex / 任意 CLI</b></summary>

```bash
git clone https://github.com/Wanbao114514/chaoxing-watch.git /tmp/chaoxing-watch
mkdir -p ~/.agents/skills/chaoxing-watch
cp -r /tmp/chaoxing-watch/. ~/.agents/skills/chaoxing-watch/
codex exec -s danger-full-access --skip-git-repo-check "看学习通《XX》第 1.1 节"
```

窗口动作改用 `scripts/win-minimize.ps1`（Windows）或 `osascript`（macOS）。

</details>

<details>
<summary><b>装到哪个目录</b></summary>

按你用的 agent 选一个目录放进去就行：

| Agent | 放这里 |
| --- | --- |
| DeepSeek Harness（全局） | `~/.dsh/skills/chaoxing-watch/` |
| DeepSeek Harness（只在某个项目里用） | `<项目>/.dsh/skills/chaoxing-watch/` |
| Codex / 其它读 `~/.agents` 的工具 | `~/.agents/skills/chaoxing-watch/` |

同一个 skill 出现在多个目录时，DSH 只用优先级最高的那份（项目级 > `~/.dsh` > `~/.agents`），不会合并。

</details>

### 建议顺手装 `dsh-ops`（省 token）

Agent 跑任务时会反复读文件、翻日志、贴长输出——这些都会按轮次重新进上下文。装 [`dsh-ops`](https://github.com/T-Auto/dsh-ops) 后，这类操作换成**有界输出**（行号范围、分页、结果预算、批量读、结果引用），能少带不少冗余内容。

在 DSH 插件市场里搜 **`dsh-ops`**（自定义源填华为云 npm 镜像 `https://mirrors.huaweicloud.com/repository/npm/`），或命令行：

```bash
npx --yes dsh-ops@latest install --profile desktop   # Web 端把 desktop 换成 web
```

它**不改变本 skill 的流程**，装不装都能跑；节省比例取决于用法（官方文档也这么说），别当成固定折扣。第三方插件，按需自行评估后再装。

---

## 第一次使用会发生什么

装好重开会话后，第一次跑任务大致是这样（DSH 视角；Codex 少了弹卡这一步）：

1. **技能出现**：技能列表里多一条 `chaoxing-watch`，不会自动运行，等你说那句话。
2. **先体检**：agent 先跑只读的 `bash ~/.dsh/skills/chaoxing-watch/scripts/bsk-daemon.sh doctor`，你看到的是——

   ```text
   [OK]   OS: MINGW64_NT-10.0-26300 x86_64
   [OK]   bash: 5.3.15(2)-release
   [OK]   nohup: /usr/bin/nohup
   [OK]   bsk CLI: /c/Users/you/bin/bsk (bsk 0.3.3)
   [WARN] daemon: 未运行（doctor 不会启动它；需要时跑 bash bsk-daemon.sh）
   检查完成：4 项通过，1 项警告，0 项失败
   ```

   `[WARN] daemon 未运行` 是正常的，接着会自动启动 daemon。
3. **macOS 首次先授权**：系统设置 → 隐私与安全性 → **辅助功能**，勾上运行 DSH 的终端（或 DSH 本体）。不授权的话最小化会报 `-1728 不允许辅助访问`，只能退成"不最小化"。
4. **缺东西会弹选择卡**：没装 `bsk` 或浏览器扩展时，agent 不会甩你一屏命令，而是弹一句「缺少 BrowserSkill，任务无法开始」，选项是 **给我安装步骤 / 我已经装好了重新检测 / 先不装**。选"装好了"会复检（最多 2 次）。Codex 等非交互环境没有这张卡，只能打印步骤并停止。
5. **会开出两个浏览器窗口**：先是一个普通窗口（新标签页），几秒后一个 1400×800 的 Agent Window 打开学习通，普通窗口会被自动关掉，窗口底部出现"Agent 正在控制"条。第一次看到"一开一关"是正常流程，不是弹广告。
6. **没登录就停**：只会回一句"学习通未登录，任务已停止……"，不会去点登录框；登录后重说一遍即可。
7. **动手前会问你**：同名课有多门时选哪个、只说了课程没给节时做哪一节、章节测验是"直接交还是先看"。

卡在第一步就看 `[FAIL]` 那行：`命名管道被拦截` = Windows 文件策略不是 `danger-full-access`；`bsk CLI 未找到` = 按卡片里的步骤安装。逐项说明在 [SKILL.md §0.1](SKILL.md)。

---

## 用法

一条指令三段：**叫 skill** → **说哪门课、哪几节** → **说测验交不交**。

```text
/chaoxing-watch 看《高等数学A(1)》3.2 节
/chaoxing-watch 推进《大学英语（一）》3.2、3.3 两节，章节测验直接提交
/chaoxing-watch 把《线性代数》4.1 的章节测验做了，答案先给我看
```

课程名可简写（"高数"→"高等数学A(1)"）。**同名课程 / 多个班**会先列出来问你，不会替你猜。说"这门课全部 / 剩下的"就从第一个未完成的节开始，只报课程名没给节会问你做哪一节。**不写交不交**时：交互场景会问一句，Codex 等非交互场景默认只填不交。多节默认做完一节停住，要连着做请说"连着做，别停"。

---

## 成本参考

DSH + `deepseek-flash` 低思考档、空闲时段跑一节：**20 分钟视频 + 5 题章节测验 ≈ 0.05 元**（按输入约 10 万、输出约 1 万 token 估；高峰时段翻倍，以账单为准）。

这个数是**DSH 下的**。换到其它 agent 环境也能跑，但窗口、截图、播放器状态都要靠脚本和额外轮次补，**同一条成本会显著上升**，别把这个数当通用标准。

---

## 运行时注意

- **会有两个浏览器窗口**：普通窗口 + Agent Window（真正在操作的那个）。收普通窗口只能用 `powershell -NoProfile -File scripts/win-minimize.ps1 -Hwnd <NORMAL> -Action close`，**别用 `alt+F4`**——焦点在 Agent Window 上时会把它关掉，整条 bsk 链路一起断。
- **别去点 Agent Window 里的页面**：那个窗口由 agent 操作，你在里面点击/输入/滚动会抢焦点、改页面状态（可能触发暂停，甚至误提交）。看看进度没关系，别动页面；自己的标签页不受影响。
- **macOS 最小化看浏览器**：Chrome 走 `miniaturized`；Edge 的 AppleScript 字典没有这个属性，要靠 System Events + 辅助功能授权。没授权时 agent 会明确报"无法最小化"并保留窗口（不影响播放），不会假装已最小化。
- **别关正在播放的页面、别退出浏览器**：窗口最小化、切到别的程序、熄屏在**实测环境（Windows 11 + Edge / macOS，2026-10）**下进度照常推进；其它浏览器/版本仍可能后台节流，播放循环会一直复查，真停了会补点。
- **熄屏 / 锁屏 / 真睡眠醒来后复查一次**：实测唤醒后能续播；长时间断网仍可能让 daemon 到期，卡住就让 agent 补点播放，仍不动就 `scripts/bsk-daemon.sh` 重开。
- **任务没结束别 `stop session`**：Agent Window 一关，浏览器退出，所有 `bsk_*` 失效。
- **答题模块最小化也能答**：实测最小化下截图、点选、提交都正常，只要宽度别低于 1200。
- **收尾会关 daemon**：`bsk-daemon.sh stop` 是整机的，脚本发现还有别的活动 session 会拒绝停止（打印 `SKIP:`），避免误伤另一个任务；确认要关用 `stop --force`。
- **截图不落仓库**：缓存目录由 `scripts/cache.sh init` 建（0700；Windows 上 `/tmp` 即 `%TEMP%`），收尾 `cache.sh clean` 删掉；中途断线残留会在下次 `init` 时自动清理。

---

## 出问题时

先让 agent 跑 `bash scripts/bsk-daemon.sh doctor`（只检查不启动）：它能定位四类问题——没装 bsk / daemon 没起 / 命名管道被沙箱拦 / 没连浏览器。逐项处理见 [SKILL.md §0.1](SKILL.md)，排障表见 [§6](SKILL.md)。

---

## 验证状态

主流程（认课 → 播放到任务点完成；进测验 → 作答 → 提交）实测跑通（2026-10）：

| 验证项目 | 结果 | 记录 |
| --- | --- | --- |
| Windows + DSH | ✅ 完整跑通 | 测试日期 2026-10 |
| Windows + Codex CLI | ✅ 完整跑通 | `-s danger-full-access`，窗口用 `win-minimize.ps1` |
| macOS + DSH | ✅ 完整跑通 | 测试日期 2026-10 |
| macOS + CLI | ✅ 完整跑通 | 窗口用 `osascript` |
| 异常恢复 | ✅ 已覆盖 | 暂停补点、daemon 断连重开、窗口误操作后恢复 |

边界项也已覆盖：macOS 最小化下截图/答题、熄屏锁屏、真睡眠唤醒后续播、播放暂停后补点。✅ 仍只代表 2026-10 这套环境；换浏览器大版本或超星改版后需要重测。

---

## 限制

只处理**视频任务点**与**章节测验**；阅读、文档、PPT、讨论、作业、考试不碰，遇到会报"跳过"。题干被私有字体混淆，只能靠截图读。超星改版可能让选择器 / 文案失效。答案由模型生成，正确率不保证。

倍速、轮询节奏、完成判据都在 SKILL.md 的对应章节（§2–§3），改这些不用动流程。

如果在多个目录各放了一份，用 `bash scripts/sync-copies.sh status` 检查是否一致（只读，有差异退出 3）。

---

## Contributors

| 成员 | 角色 |
| --- | --- |
| [@Wanbao114514](https://github.com/Wanbao114514) | 作者 / 维护 |
| DeepSeek | 共同开发（流程梳理、脚本文档与历次评审） |

---

## License

MIT。仅用于**个人学习辅助**，请自行遵守所在学校规定与学习通平台服务条款；不提供账号、不代登录、不绕过验证码，作者不对成绩或使用后果负责。
