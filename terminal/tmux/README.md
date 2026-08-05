# tmux 使用与工程经验

> 核查日期：2026-08-05。命令以 tmux 3.x 为基准；服务器发行版自带版本可能更旧，使用前先执行 `tmux -V`。

## 解决的问题

tmux 是通用终端复用器。它在后台运行一个 server，由 server 持有多个伪终端（PTY）及其中的进程；一个或多个 client 可以连接到 server，查看和操作这些终端。

它主要解决：

- SSH 断开后，交互式程序仍继续运行；
- 在一个终端中组织多个 Shell、编辑器、日志、构建和调试进程；
- 从不同终端重新连接同一工作现场；
- 通过命令和目标语法自动创建、控制和读取终端。

它不解决：

- 主机重启后的进程恢复；
- 服务自动拉起、健康检查、资源限制和依赖排序；
- 任务是否正确完成；
- 进程级内存检查点和迁移。

生产服务应由 systemd、容器编排或任务调度系统管理；tmux 更适合作为交互控制面和排障现场。

---

## 对象模型

```text
tmux server
└── session: project-a
    ├── window: editor
    │   └── pane: vim
    ├── window: build
    │   ├── pane: cmake --build
    │   └── pane: ctest
    └── window: logs
        └── pane: tail -F app.log
```

- **server**：后台主进程，保存全部 tmux 状态并持有 PTY；
- **client**：当前外部终端与 tmux server 的连接；
- **session**：一组 windows，通常映射一个项目、主机任务或排障现场；
- **window**：一组 panes，通常映射一个功能视图；
- **pane**：一个真实终端及其中运行的前台进程。

关键边界：

```text
关闭 client / SSH 断线
!=
删除 session / 杀死 server
```

前者只断开观察入口，后者会结束对应 PTY 及其中的进程。

---

## 安装与检查

Ubuntu / Debian：

```bash
sudo apt update
sudo apt install tmux
```

RHEL / Rocky / AlmaLinux：

```bash
sudo dnf install tmux
```

检查版本和 server：

```bash
tmux -V
tmux list-sessions 2>/dev/null || true
pgrep -af tmux
```

发行版长期支持版本可能落后于上游。遇到配置项不存在时，先查：

```bash
tmux -V
man tmux
```

不要直接复制针对最新版本的配置并假定旧服务器支持。

---

## 最小使用闭环

### 1. 创建或连接固定 session

推荐使用幂等入口：

```bash
tmux new-session -A -s project-a
```

含义：

- session `project-a` 不存在：创建并连接；
- session 已存在：直接连接。

相比直接运行 `tmux`，固定名称更便于脚本、交接和远程重连。

### 2. 脱离而不结束任务

默认按键：

```text
Ctrl-b，然后按 d
```

这是先按 prefix `Ctrl-b`，松开后再按 `d`，不是同时按三个键。

也可以从另一个 Shell 执行：

```bash
tmux detach-client -s project-a
```

### 3. 查看并重新连接

```bash
tmux list-sessions
tmux attach-session -t project-a
```

若同一 session 已被另一终端占用，并希望踢掉旧 client：

```bash
tmux attach-session -d -t project-a
```

### 4. 正确结束

结束单个 session：

```bash
tmux kill-session -t project-a
```

结束整个 tmux server 及全部 session：

```bash
tmux kill-server
```

`kill-server` 是破坏性操作，不是 detach。

---

## 常用交互操作

默认 prefix 是 `Ctrl-b`。

| 操作 | 默认按键 |
|---|---|
| 脱离 session | `Ctrl-b d` |
| 新建 window | `Ctrl-b c` |
| 下一个 / 上一个 window | `Ctrl-b n` / `Ctrl-b p` |
| 按编号切换 window | `Ctrl-b 0..9` |
| 重命名 window | `Ctrl-b ,` |
| 左右分 pane | `Ctrl-b %` |
| 上下分 pane | `Ctrl-b "` |
| pane 间移动 | `Ctrl-b` 后按方向键 |
| 临时放大 pane | `Ctrl-b z` |
| 显示 pane 编号 | `Ctrl-b q` |
| 关闭当前 pane | `Ctrl-b x` |
| 进入复制模式 | `Ctrl-b [` |
| 查看 session/window/pane 树 | `Ctrl-b w` |
| 命令提示符 | `Ctrl-b :` |

删除 pane、window、session 都会影响其中运行的进程。看到确认提示时不要形成无条件回车的习惯。

---

## 推荐项目布局

一项目一 session，一类职责一 window：

```text
session: project-a
├── 0:editor
├── 1:build
├── 2:test
├── 3:logs
└── 4:shell
```

创建：

```bash
tmux new-session -d -s project-a -n editor -c "$HOME/code/project-a"
tmux new-window  -t project-a -n build -c "$HOME/code/project-a"
tmux new-window  -t project-a -n test  -c "$HOME/code/project-a"
tmux new-window  -t project-a -n logs  -c "$HOME/code/project-a"
tmux attach-session -t project-a
```

这种映射比“每个命令一个随机 session”更容易重连、交接和脚本定位。

### 新 pane 继承当前目录

默认新 pane 的工作目录行为容易随启动方式和版本产生差异。显式指定更可控：

```bash
tmux split-window -h -c '#{pane_current_path}'
tmux split-window -v -c '#{pane_current_path}'
```

配置为快捷键：

```tmux
bind | split-window -h -c '#{pane_current_path}'
bind - split-window -v -c '#{pane_current_path}'
```

---

## 最小配置

文件位置：

```text
~/.tmux.conf
```

建议先保持配置很小：

```tmux
# 允许鼠标选择 pane、调整大小和滚动。
set -g mouse on

# 新 pane / window 尽量继承当前 pane 的工作目录。
bind | split-window -h -c '#{pane_current_path}'
bind - split-window -v -c '#{pane_current_path}'
bind c new-window -c '#{pane_current_path}'

# window 删除后自动重排编号。
set -g renumber-windows on

# 增大每个 pane 的滚动历史；会增加 server 内存占用。
set -g history-limit 100000

# vi 风格复制模式；不需要时可删除。
setw -g mode-keys vi

# tmux 内部终端类型。前提是远端 terminfo 中存在该条目。
set -g default-terminal 'tmux-256color'
```

重新加载：

```bash
tmux source-file ~/.tmux.conf
```

检查配置是否被接受：

```bash
tmux show-options -g
tmux show-window-options -g
```

不是所有 server 级或终端能力变化都能通过 reload 完整生效；排查异常时可先用隔离 server 验证，而不是直接杀死现有任务：

```bash
tmux -L test -f /dev/null new-session
```

`-L test` 使用独立 socket 名称，不会影响默认 server。

---

## SSH 与远程服务器

典型路径：

```text
本地终端
  ↓ SSH
远程 Shell
  ↓ tmux client
远程 tmux server
  ↓
远程 PTY 和任务
```

使用：

```bash
ssh user@example.com
tmux new-session -A -s project-a
```

SSH 断线只会使 tmux client 消失；只要远程 tmux server 和主机仍在，pane 中进程继续运行。

### 不要夸大持久化

以下情况会丢失原进程：

- 服务器重启；
- tmux server 崩溃或被杀死；
- 用户的 systemd session、容器或 namespace 被清理；
- session/window/pane 被显式删除；
- pane 内的前台程序自行退出。

需要机器重启后恢复任务时，应把真实任务放入 systemd、Slurm、Kubernetes Job 等系统；tmux 只负责观察和人工控制。

---

## 脚本化与目标语法

### 后台创建并启动命令

```bash
tmux new-session -d -s build -n compile -c "$HOME/code/project-a"
tmux send-keys -t build:compile.0 'cmake --build build -j8' Enter
```

目标一般写成：

```text
session:window.pane
```

例如：

```bash
tmux list-panes -t build:compile -F '#{session_name}:#{window_name}.#{pane_index} #{pane_pid} #{pane_current_command}'
```

### 捕获 pane 输出

```bash
tmux capture-pane -p -t build:compile.0 -S -200
```

这只能读取终端历史，不等价于结构化任务结果。颜色控制序列、全屏程序重绘和截断都会影响可读性。

### `send-keys` 的边界

```bash
tmux send-keys -t build:compile.0 'make test' Enter
```

本质是向终端注入按键，而不是调用一个有类型、有确认返回值的 API。必须考虑：

- pane 是否仍是预期 Shell；
- 前台是否正运行 vim、sudo 密码提示或其他交互程序；
- 命令是否因 quoting 被外层 Shell 改写；
- Enter 是否会确认危险操作。

对关键自动化，优先直接启动非交互命令并记录 PID、退出码和日志，而不是盲目 `send-keys`。

---

## 公开经验与常见坑

本节把官方机制、常见用户故障和工程推断分开。官方 FAQ 能证明某类故障长期存在，但不能证明每个环境都应采用同一配置。

### 1. `detach`、`kill-session`、`kill-server` 混淆

**官方事实**：detach 仅断开 client；kill 会结束对应 server 对象和程序。

**工程动作**：清理脚本中禁止无条件执行：

```bash
tmux kill-server
```

先检查：

```bash
tmux list-sessions
tmux list-clients
tmux list-panes -a -F '#{session_name}:#{window_name}.#{pane_index} #{pane_current_command}'
```

### 2. `TERM` 和 terminfo 不匹配

**官方 FAQ 的高频结论**：大量颜色、按键、斜体和全屏绘制问题来自错误的 `TERM`。

检查外层：

```bash
printf 'outside TERM=%s\n' "$TERM"
```

进入 tmux 后：

```bash
printf 'inside TERM=%s\n' "$TERM"
infocmp "$TERM" >/dev/null && echo OK
```

内部一般应是 `tmux`、`tmux-256color`、`screen` 或相应变体。若远端没有 `tmux-256color` terminfo，直接强设会使程序异常；可安装 terminfo，或退回实际存在的类型。

### 3. 嵌套 tmux 导致 prefix 和剪贴板链路复杂

**公开经验**：本地 tmux → SSH → 远端 tmux 很常见，但默认都使用 `Ctrl-b`，按键先被外层截获。

可选择：

- 避免嵌套；
- 给内外层使用不同 prefix；
- 需要向内层发送 literal prefix 时使用两次 prefix。

嵌套还会增加 `TERM`、OSC 52 和窗口尺寸链路，排错成本显著上升。

### 4. 剪贴板不是单一 tmux 配置问题

系统剪贴板可能依赖：

```text
tmux copy-mode
  ↓
OSC 52 或外部复制程序
  ↓
外层终端能力与安全设置
  ↓
本地操作系统剪贴板
```

官方文档指出，OSC 52 支持在终端间并不一致。`set-clipboard on` 还允许 pane 中应用通过控制序列设置外部剪贴板；运行不可信命令时需要评估安全边界。

先检查：

```bash
tmux show-options -s set-clipboard
```

不要从网络复制一段剪贴板配置后，在不了解外层终端支持的情况下反复叠加插件。

### 5. 旧 session 中的环境变量不会自动回写到既有进程

tmux server 和新 pane 会继承或更新一部分环境，但已经运行的 Shell 是独立进程，不能被 tmux 反向修改其进程环境。

典型表现：

- 新 SSH 登录的 `SSH_AUTH_SOCK` 已变化；
- 旧 pane 内仍引用失效 socket；
- 代理、CUDA、Conda 等变量在不同 pane 不一致。

检查：

```bash
tmux show-environment -g
echo "$SSH_AUTH_SOCK"
```

修复策略是让新 pane 从可靠的 Shell 启动文件加载环境，或显式更新 tmux environment 后新建 pane；不要假设已有 Shell 自动同步。

### 6. 多 client 的窗口尺寸相互影响

同一 session 可被多个 client 连接。小尺寸终端、手机或遗留 client 可能影响可见布局。

检查：

```bash
tmux list-clients -F '#{client_tty} #{client_width}x#{client_height} #{client_session}'
```

需要独占连接时：

```bash
tmux attach-session -d -t project-a
```

### 7. `synchronize-panes` 会把输入广播到多个 pane

它适合对多台机器执行同一只读命令，也可能把删除、重启、密码或确认输入广播出去。

检查当前窗口：

```bash
tmux show-window-options synchronize-panes
```

执行危险操作前必须确认已关闭：

```bash
tmux set-window-option synchronize-panes off
```

### 8. 过度定制会降低可迁移性

**公开使用经验**：大型状态栏、插件管理器和大量重绑键可以提高个人效率，也会带来版本依赖、远程机器缺插件、复制行为不同和排错困难。

推荐顺序：

1. 先掌握 session/window/pane 和目标语法；
2. 保持一份无插件最小配置；
3. 只为重复出现的问题增加配置；
4. 在受限服务器上优先使用默认键位。

### 9. tmux 不是任务完成证明

pane 仍存在，只能证明终端还存在；命令退出，也不代表任务成功。

长期任务至少应记录：

```bash
command 2>&1 | tee run.log
status=${PIPESTATUS[0]}
printf '%s\n' "$status" > run.exit-code
exit "$status"
```

验收应读取退出码、产物、测试报告和业务指标，不应仅观察 pane 是否安静。

---

## 系统化排错

### 1. 确认版本、server 和 socket

```bash
tmux -V
pgrep -af tmux
tmux list-sessions
tmux display-message -p '#{socket_path}'
```

若 tmux 进程仍在但 `/tmp` socket 被删除，官方 FAQ 建议向 tmux server 发送 `USR1` 让其重建 socket：

```bash
pkill -USR1 tmux
```

执行前先确认目标用户和进程，避免误发给其他人的 tmux。

### 2. 确认对象层级

```bash
tmux list-clients
tmux list-sessions
tmux list-windows -a
tmux list-panes -a -F '#{session_name}:#{window_name}.#{pane_index} pid=#{pane_pid} cmd=#{pane_current_command} dead=#{pane_dead}'
```

### 3. 确认终端能力

```bash
printf 'TERM=%s COLORTERM=%s\n' "$TERM" "${COLORTERM-}"
infocmp "$TERM"
tmux show-options -g default-terminal
```

### 4. 隔离配置

```bash
tmux -L clean -f /dev/null new-session
```

若干净 server 正常，问题大概率来自用户配置或插件；若仍异常，再检查外层终端、SSH 和 terminfo。

### 5. 查看 server 日志

启动隔离 server 并增加调试：

```bash
tmux -L debug -vv new-session
```

当前目录会生成 `tmux-client-*`、`tmux-server-*`、`tmux-out-*` 日志。不要在包含敏感终端内容的情况下直接公开上传。

---

## 推荐长期用法

```text
交互式、可人工接管、允许仅在主机在线期间持续
    → tmux

需要主机重启后自动恢复、资源治理、依赖和健康检查
    → systemd / container / scheduler

需要管理多个 Coding Agent 的语义状态和编排
    → 评估 Herdr，同时保留 tmux 作为通用兜底
```

一个稳定入口即可覆盖大多数使用：

```bash
tmux new-session -A -s project-a
```

先建立可靠的 session 命名、detach/attach、日志和验收习惯，再增加插件和自动化。

---

## 资料来源

### 官方资料

- tmux Wiki：https://github.com/tmux/tmux/wiki
- Getting Started：https://github.com/tmux/tmux/wiki/Getting-Started
- FAQ：https://github.com/tmux/tmux/wiki/FAQ
- Clipboard：https://github.com/tmux/tmux/wiki/Clipboard
- 本机完整参考：`man 1 tmux`

### 证据边界

- tmux 对象模型、命令语义和配置项来自官方 Wiki 与手册；
- “常见坑”优先使用官方 FAQ 中反复出现的故障类型；
- 关于目录组织、最小配置、避免过度定制和验收方式的内容是工程建议，不是 tmux 官方保证；
- 具体终端、发行版和 tmux 版本可能改变按键、termInfo 和剪贴板行为，出现冲突时以当前机器的 `man tmux` 与实际测试为准。