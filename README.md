# chaoxing-watch

在学习通（超星）网页版按章节推进课程的小技能，给能跑 shell 的 AI Agent 用 —— DeepSeek Harness、Codex，或任何能执行命令的 CLI。

大学里大量通识课的任务点只是时长统计：这个 skill 把机械的"看完 / 点完"交给自动化，把时间留给真正要学的课。**不做代考、不绕过考试、不伪造学习记录**——进度是真播完的，题也是真答的。

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

---

## 用法

一条指令三段：**叫 skill** → **说哪门课、哪几节** → **说测验交不交**。

```text
/chaoxing-watch 看《高等数学A(1)》3.2 节
/chaoxing-watch 刷《大学英语（一）》3.2、3.3 两节，章节测验直接提交
/chaoxing-watch 把《线性代数》4.1 的章节测验做了，答案先给我看
```

课程名可简写（"高数"→"高等数学A(1)"）；不给节号就从上往下找第一个未完成的节。**不写交不交**时：交互场景会问一句，Codex 等非交互场景默认只填不交。多节默认做完一节停住，要连着做请说"连着做，别停"。

---

## 运行时注意

- **会有两个浏览器窗口**：普通窗口 + Agent Window（真正在操作的那个）。收普通窗口只能用 `powershell -NoProfile -File scripts/win-minimize.ps1 -Hwnd <NORMAL> -Action close`，**别用 `alt+F4`**——焦点在 Agent Window 上时会把它关掉，整条 bsk 链路一起断。
- **别关正在播放的页面、别退出浏览器**：窗口最小化、切到别的程序、熄屏都不影响（实测进度照常推进）。
- **熄屏 / 锁屏不用管**：实测进度照常推进。**真睡眠没实测**，按一般逻辑处理最稳——醒来让 agent 读一次播放状态，卡住就补点，daemon 掉了就 `scripts/bsk-daemon.sh` 重开。
- **任务没结束别 `stop session`**：Agent Window 一关，浏览器退出，所有 `bsk_*` 失效。
- **答题模块最小化也能答**：实测最小化下截图、点选、提交都正常，只要宽度别低于 1200。

---

## 出问题时

先让 agent 跑 `bash scripts/bsk-daemon.sh doctor`：只检查不启动，会分四类报——没装 bsk / daemon 没起 / 命名管道被沙箱拦 / 没连浏览器。

还不行就看 [SKILL.md §7](SKILL.md) 的排障表。

---

## 限制

只处理**视频任务点**与**章节测验**；阅读、文档、PPT、讨论、作业、考试不碰，遇到会报"跳过"。题干被私有字体混淆，只能靠截图读。超星改版可能让选择器 / 文案失效。答案由模型生成，正确率不保证。

倍速、轮询节奏、完成判据都在 SKILL.md 的对应章节（§2–§4），改这些不用动流程。

如果在多个目录各放了一份，用 `bash scripts/sync-copies.sh status` 检查是否一致（只读，有差异退出 3）。

---

## License

MIT。仅用于**个人学习辅助**，请自行遵守所在学校规定与学习通平台服务条款；不提供账号、不代登录、不绕过验证码，作者不对成绩或使用后果负责。
