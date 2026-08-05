# tmux 启动目录与 Shell 初始化链路

> 核查日期：2026-08-05。本文处理一个独立问题：tmux 已通过 `-c` 或命令中的 `cd` 指定目录，但进入 pane 后 Shell 仍跳到其他目录。

## 现象

执行：

```bash
tmux new-session -A -s project-a -c /path/to/project
```

进入 tmux 后却位于 `/`、`$HOME` 或其他目录。

即使改为：

```bash
tmux new-session -s project-a \
  "cd /path/to/project && exec bash"
```

最终目录仍可能被改写。

一个已经核实的真实原因是：

```bash
# ~/.bashrc
cd /
```

删除该命令后，tmux 的 `-c` 正常生效；保留原配置但改用：

```bash
tmux new-session -s project-a \
  "cd /path/to/project && exec bash --noprofile --norc"
```

也可以进入目标目录。

这两种结果共同说明：tmux 已正确设置初始工作目录，真正覆盖目录的是后续启动的 Bash 初始化脚本。

---

## 问题本质

当前工作目录不是“终端窗口的属性”，而是**每个进程在内核中的状态**。

一条典型链路是：

```text
终端模拟器
    ↓
SSH client / SSH server（可选）
    ↓
tmux client
    ↓
tmux server
    ↓
PTY
    ↓
Shell 进程
    ↓
Shell 启动文件中的命令
```

`tmux new-session -c /path/to/project` 做的是：

1. tmux server 创建新的 pane 和 PTY；
2. 在目标目录中启动 pane 的子进程；
3. 子进程继承这个 cwd；
4. tmux 再启动配置的 Shell；
5. Shell 根据自己的启动模式读取初始化文件；
6. 初始化文件中的 `cd` 可以再次修改 Shell 自己的 cwd。

因此存在两个连续但相互独立的动作：

```text
tmux 设置初始 cwd
        ↓
Shell 启动
        ↓
Shell 初始化脚本可能再次执行 cd
```

后一步发生时，前一步并没有失败，只是结果被覆盖了。

---

## `-c` 到底控制什么

`new-session`、`new-window` 和 `split-window` 的 `-c` 都用于指定**新创建进程的起始目录**。

例如：

```bash
tmux new-session -s project-a -c /path/to/project
```

适用于新建 session。

```bash
tmux new-window -t project-a -n build -c /path/to/project
```

适用于新建 window。

```bash
tmux split-window -h -c '#{pane_current_path}'
```

适用于新建 pane，并继承当前 pane 的目录。

它不保证：

- 已存在的 session、window 或 pane 被重新 `cd`；
- Shell 初始化脚本不会修改目录；
- pane 中前台程序退出后启动的下一个 Shell 保持同一目录；
- 容器 entrypoint、远程 Shell 或其他包装脚本不会再次修改 cwd。

### `-A` 的额外语义

```bash
tmux new-session -A -s project-a -c /path/to/project
```

含义是：

- `project-a` 不存在：创建新 session，`-c` 用于新 pane；
- `project-a` 已存在：连接已有 session，已有 pane 的 cwd 不会被重建。

因此排查时必须先区分：

```text
连接了已有 pane
```

还是：

```text
新 pane 启动后又被 Shell 改目录
```

这两个现象表面相同，根因不同。

---

## 为什么命令中的 `cd` 也会失效

下面的命令不是最终强制目录：

```bash
tmux new-session -s project-a \
  "cd /path/to/project && exec bash"
```

实际顺序是：

```text
包装 Shell 执行 cd /path/to/project
        ↓
exec bash 替换当前进程
        ↓
新 Bash 发现自己是交互式 Shell
        ↓
读取 ~/.bashrc
        ↓
~/.bashrc 中的 cd / 再次改变 cwd
```

所以 `cd` 的确成功过，只是随后又被执行了一次新的 `cd`。

这是 Shell 启动链路问题，不是 tmux 忽略命令。

---

## Bash 启动文件的关键区别

Bash 是否读取某个文件，取决于它是不是：

- interactive shell；
- login shell；
- non-interactive shell；
- 以 `sh` 名称启动；
- 由远程守护进程启动。

最常见的简化关系如下：

| Bash 类型 | 主要启动文件 |
|---|---|
| 交互式 login shell | `/etc/profile`，随后读取 `~/.bash_profile`、`~/.bash_login`、`~/.profile` 中第一个存在的文件 |
| 交互式 non-login shell | `~/.bashrc` |
| 非交互式 Bash | 默认不读取 `~/.bashrc`，但可能读取 `$BASH_ENV` 指定文件 |
| `bash --noprofile --norc` | 不读取 login profile，也不读取交互式 `~/.bashrc` |

大多数 tmux pane 启动的是交互式、非 login Bash，因此通常直接读取：

```text
~/.bashrc
```

但实际机器还可能有以下链路：

```text
~/.bash_profile
    ↓ source
~/.bashrc
```

或者：

```text
/etc/bash.bashrc
    ↓
~/.bashrc
```

所以不能只凭文件名判断，必须检查实际 source 关系。

---

## 两种已验证的解决方案

### 主方案：删除全局启动脚本中的无条件 `cd`

```bash
# 不推荐
cd /
```

Shell 启动文件应主要负责：

- 环境变量；
- PATH；
- alias 和 function；
- prompt；
- 交互行为配置。

无条件改变目录会影响：

- 普通终端；
- SSH 登录；
- tmux / screen / Herdr pane；
- VS Code Remote Terminal；
- IDE 集成终端；
- 自动化脚本启动的交互 Shell；
- 容器中的调试 Shell。

推荐改成显式入口：

```bash
cproj() {
    cd /path/to/project || return
}
```

或者直接让 tmux 入口负责目录：

```bash
tmux new-session -A -s project-a -c /path/to/project
```

核心原则是：

> 项目目录属于具体工作入口，不应成为所有 Shell 的全局副作用。

### 诊断或隔离方案：启动不读取配置的 Bash

```bash
tmux new-session -s project-a \
  "cd /path/to/project && exec bash --noprofile --norc"
```

该命令适合验证：

```text
问题是否来自 Bash 启动文件
```

若它能进入正确目录，而普通 Bash 不能，说明应继续检查：

- `~/.bashrc`；
- `~/.bash_profile`；
- `~/.bash_login`；
- `~/.profile`；
- `/etc/profile`；
- `/etc/bash.bashrc` 或发行版对应的系统级文件；
- 被这些文件 `source` 的其他脚本。

不建议把 `--noprofile --norc` 永久作为默认 Shell，因为它也会跳过：

- 用户 PATH 修改；
- Conda、SDK、工具链初始化；
- alias 和 function；
- prompt 配置；
- SSH agent 或代理相关环境修复；
- 其他必要交互配置。

它是一个高价值的**隔离实验**，不是默认环境治理方案。

---

## 系统化定位步骤

### 第 1 步：确认目录本身有效

```bash
target=/path/to/project

[[ -d "$target" ]] || {
    printf 'directory does not exist: %s\n' "$target" >&2
    exit 1
}

cd "$target" && pwd -P
```

先排除路径不存在、权限不足、挂载未完成和软链接异常。

### 第 2 步：避免误连已有 session

```bash
tmux has-session -t project-a 2>/dev/null && \
    tmux kill-session -t project-a

tmux new-session -s project-a -c /path/to/project
```

注意：`kill-session` 会终止该 session 中的进程，执行前必须确认没有需要保留的任务。

也可以使用隔离 tmux server，完全不影响已有工作：

```bash
tmux -L cwd-test -f /dev/null \
    new-session -s project-a -c /path/to/project
```

`-L cwd-test` 使用独立 socket；`-f /dev/null` 暂时排除 `~/.tmux.conf`。

### 第 3 步：读取 tmux 观察到的 pane cwd

在 tmux 外执行：

```bash
tmux display-message -p \
  -t project-a:0.0 \
  '#{pane_current_path}'
```

查看 pane 进程：

```bash
tmux list-panes -t project-a \
  -F 'pid=#{pane_pid} cmd=#{pane_current_command} cwd=#{pane_current_path}'
```

如果这里已经显示 `/`，说明当前前台 Shell 的 cwd 已被改写；这不能单独证明 tmux 最初没有设置目标目录。

### 第 4 步：用干净 Bash 做区分实验

```bash
tmux -L cwd-clean -f /dev/null \
  new-session -s project-a \
  "cd /path/to/project && exec bash --noprofile --norc"
```

结果解释：

| 结果 | 更可能的原因 |
|---|---|
| 干净 Bash 正常，普通 Bash 错误 | 用户或系统 Shell 初始化文件修改了 cwd |
| 干净 Bash 仍错误 | 路径、权限、挂载、包装命令或 tmux 版本/调用方式仍需检查 |
| 只有 `-A` 时错误 | 实际连接的是已有 session/pane |
| 新 session 正常，新 window/pane 错误 | 创建 window/pane 时没有显式传 `-c`，或快捷键绑定覆盖了默认行为 |

### 第 5 步：搜索启动脚本中的目录修改

```bash
grep -nE '(^|[;&[:space:]])(builtin[[:space:]]+)?cd([[:space:]]|$)' \
  ~/.bashrc \
  ~/.bash_profile \
  ~/.bash_login \
  ~/.profile \
  2>/dev/null
```

继续检查 source 链：

```bash
grep -nE '(^|[;&[:space:]])(source|\.)[[:space:]]+' \
  ~/.bashrc \
  ~/.bash_profile \
  ~/.bash_login \
  ~/.profile \
  2>/dev/null
```

系统级文件需要按发行版检查：

```bash
grep -nE '(^|[;&[:space:]])(builtin[[:space:]]+)?cd([[:space:]]|$)' \
  /etc/profile \
  /etc/bash.bashrc \
  2>/dev/null
```

不要只搜索字面量 `cd /`，因为目录变化也可能来自：

- function；
- alias；
- 被 source 的脚本；
- `PROMPT_COMMAND`；
- `direnv`、zoxide 等目录工具；
- 自定义 Shell 框架；
- IDE 或容器包装命令。

### 第 6 步：确认 Shell 启动类型

在问题 pane 中执行：

```bash
printf 'shell=%s\n' "$SHELL"
printf 'argv0=%s\n' "$0"
printf 'flags=%s\n' "$-"
shopt -q login_shell && echo 'login shell' || echo 'non-login shell'
[[ $- == *i* ]] && echo 'interactive shell' || echo 'non-interactive shell'
```

这一步用于确认应当检查哪组启动文件，而不是凭经验猜测。

---

## 推荐的稳定入口

```bash
#!/usr/bin/env bash
set -euo pipefail

session='project-a'
target='/path/to/project'

[[ -d "$target" ]] || {
    printf 'target directory does not exist: %s\n' "$target" >&2
    exit 1
}

exec tmux new-session -A -s "$session" -c "$target"
```

前提是 Shell 初始化脚本不再无条件修改 cwd。

若需要确认最终目录，可以新建后检查：

```bash
tmux display-message -p \
  -t project-a:0.0 \
  '#{pane_current_path}'
```

---

## 常见误区

### 误区 1：`-c` 是持续目录锁

不是。`-c` 只设置新进程的起始目录，进程之后可以自由执行 `cd`。

### 误区 2：`cd && exec bash` 一定能锁定目录

不是。新的交互式 Bash 仍会读取启动文件；其中的 `cd` 可以再次覆盖目录。

### 误区 3：删除 session 后仍失败，就说明 tmux 有 bug

不一定。删除 session 只能排除“连接已有 pane”，不能排除 Shell 初始化脚本、系统级配置和包装命令。

### 误区 4：长期使用 `--noprofile --norc` 最干净

它确实更干净，但也绕过了真实开发环境。长期依赖它会隐藏 PATH、SDK、Conda 和工具链初始化问题。

### 误区 5：把默认项目目录写进 `~/.bashrc` 最省事

它把一个项目入口扩散成所有交互式 Shell 的副作用，会使终端、SSH、tmux、IDE 和自动化行为互相污染。

---

## 结论

本案例的稳定判断是：

```text
tmux -c / command 中的 cd
    负责设置初始 cwd

Bash 启动文件
    可以在 Shell 启动后再次修改 cwd
```

当 `-c` 和显式 `cd` 都看似失效时，最有区分力的实验不是继续叠加 tmux 参数，而是：

```bash
exec bash --noprofile --norc
```

如果干净 Bash 正常，就应修复 Shell 初始化文件；在已核实案例中，删除 `~/.bashrc` 中的 `cd /` 后恢复正常。

---

## 资料来源

### 官方资料

- tmux 完整参考：`man 1 tmux`
- tmux Wiki：https://github.com/tmux/tmux/wiki
- GNU Bash：Bash Startup Files：https://www.gnu.org/software/bash/manual/html_node/Bash-Startup-Files.html
- GNU Bash：Invoking Bash：https://www.gnu.org/software/bash/manual/html_node/Invoking-Bash.html
- GNU Bash：Is this Shell Interactive?：https://www.gnu.org/software/bash/manual/html_node/Is-this-Shell-Interactive_003f.html

### 证据边界

- tmux `-c` 的语义和 pane 目录检查方法属于工具机制；
- Bash 启动文件和 `--noprofile`、`--norc` 的行为来自 GNU Bash 官方手册；
- `~/.bashrc` 中存在 `cd /`、删除后恢复、使用干净 Bash 同样恢复，是本次可定位工程案例；
- 不应由单个案例推断所有 `-c` 故障都来自 `.bashrc`，排查仍需区分已有 session、路径/权限、系统级启动文件和其他包装层。