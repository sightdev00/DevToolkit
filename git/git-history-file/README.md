# git-history-file

查询某类文件在 Git 历史中的真实实体变化，而不是只查看最近若干个普通提交。

适用于动态库、模型、固件和其他二进制制品的历史核查：

- 哪些提交真正改变了目标文件；
- 文件在提交后的内容校验值与大小；
- 文件是新增、修改、删除还是类型变化；
- 两个发布记录中的文件名不同，但实体内容是否相同。

## 使用方法

```bash
./git-history-file.sh \
  --pattern '(^|/)libexample\.so(\.[0-9]+)*$' \
  --limit 10
```

从指定版本开始查询模型文件，并使用 SHA-256：

```bash
./git-history-file.sh \
  --pattern '(^|/)models/.*\.onnx$' \
  --limit 5 \
  --hash sha256 \
  --revision release/1.2
```

`REV` 也可以作为唯一的位置参数：

```bash
./git-history-file.sh \
  --pattern '(^|/)firmware/.*\.bin$' \
  v2.0.0
```

## 参数

| 参数 | 含义 |
|---|---|
| `-p, --pattern REGEX` | 匹配仓库相对路径的扩展正则表达式，必选 |
| `-n, --limit COUNT` | 最近多少次“匹配文件发生变化的提交”，默认 10 |
| `--hash sha256\|md5` | 内容校验算法，默认 SHA-256 |
| `--sha256` / `--md5` | 校验算法快捷选项 |
| `-r, --revision REV` | 历史遍历起点，默认 `HEAD` |

## 输出

```text
commit: a1b2c3d
date:   2026-07-03 16:51:00 +0800
msg:    update model artifact

  modified   7af6...  123456       models/example.onnx
  deleted    -        -            models/legacy.onnx
```

输出的校验值针对该提交 tree 中保存的 blob 内容。若文件由 Git LFS 管理，默认计算的是 LFS pointer 的内容，而不是远端 LFS 实体。

## 与普通 Git 查询的区别

```bash
git rev-list -n 10 HEAD
```

回答的是“最近 10 个仓库提交”。这些提交可能都没有修改目标文件。

```bash
git log -- path/to/file
```

适合精确路径，但不直接解决一组正则匹配文件的实体身份、大小和删除状态问题。

本工具持续遍历历史，直到找到指定数量的目标文件变化提交。

## 运行要求

- Bash 4 及以上版本；
- Git；
- GNU `sort`、`awk`；
- `sha256sum` 或 `md5sum`。

macOS 默认缺少 GNU checksum 命令，需要安装 GNU coreutils，或在兼容环境中运行。

## 行为边界

- 使用 `git diff-tree -m` 检查 merge commit；同一路径相对多个父提交出现时按路径去重；
- 使用 `--no-renames`，rename 会表现为删除旧路径并新增新路径；
- 路径匹配使用 Bash 扩展正则表达式，不是 shell glob；
- 文件名包含换行符时，最终排序输出不受支持；普通空格不受影响；
- MD5 仅适合快速内容比较，默认使用 SHA-256；
- 工具确认的是文件实体变化，不分析 ELF ABI、模型语义或代码逻辑差异。

## 退出码

| 退出码 | 含义 |
|---|---|
| `0` | 查询成功 |
| `1` | 仓库、revision 或 Git 对象读取失败 |
| `2` | 参数或正则表达式错误 |
| `3` | 未找到匹配变化 |
| `127` | 缺少运行依赖 |

## 安装

```bash
install -m 0755 \
  git/git-history-file/git-history-file.sh \
  ~/.local/bin/git-history-file
```
