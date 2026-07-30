# Git 工具

## `history-file-md5.sh`

用于查找最近若干个**真正修改过目标文件**的提交，并输出这些文件在对应提交后的 MD5。

匹配对象是仓库相对路径，使用扩展正则表达式（`grep -E`）。

## 为什么需要这个工具

直接遍历：

```bash
git rev-list -n N HEAD
```

回答的是“最近 N 个仓库提交是什么”，但这些提交中的大多数可能没有修改目标文件。

本工具会持续向历史遍历，直到找到 N 个真正修改过目标文件的提交。

它同时规避了几类常见问题：

- shell 通配符不会自动在历史 Git tree 中展开；
- 在仓库子目录执行时，容易丢失 `git cat-file` 所需的仓库相对路径；
- `git cat-file` 失败后继续进入管道，可能错误地产生空输入的 MD5：`d41d8cd98f00b204e9800998ecf8427e`；
- 删除文件不存在“提交后的 MD5”，需要单独标记。

## 运行要求

- Bash 4 及以上版本（使用了 `mapfile`）；
- Git；
- GNU `grep`、`sort`、`md5sum` 和 `awk`。

macOS 默认没有 `md5sum`，可安装 GNU coreutils 后使用 `gmd5sum`，或自行提供兼容命令。

## 基本用法

```bash
bash git/history-file-md5.sh \
  -n 10 \
  -r '(^|/)libexample\.so\.1\.2[^/]*$'
```

脚本可以从目标 Git 仓库的任意子目录执行，会自动切换到仓库根目录。

指定其他起始版本：

```bash
bash git/history-file-md5.sh \
  -n 5 \
  -r '(^|/)libsample\.so(\.[0-9]+)*$' \
  release/1.2
```

## 输出示例

```text
a1b2c3d 2026-07-03 16:51:00 +0800 update library
  7af6...  path/to/libexample.so.1.2.3
```

删除文件显示为：

```text
  DELETED                           path/to/libexample.so.1
```

## 参数语义

- `-n`：统计“修改过匹配文件的提交数”，不是遍历的普通提交总数；
- `-r`：扩展正则表达式，不是 shell glob；
- `REV`：可选的历史起点，默认是 `HEAD`。

## 行为与限制

- 脚本通过 `git diff-tree -m` 检查 merge commit；当合并结果相对至少一个父提交发生变化时，该 merge commit 可能被列出；
- 输出的是文件在该提交完成后的 MD5；
- 文件被删除时没有提交后的校验值，只显示 `DELETED`；
- MD5 只适合快速判断文件内容是否一致，不适用于安全校验或对抗性场景；安全敏感场景应使用 SHA-256；
- 示例中的库名、路径和提交信息均为脱敏占位内容。

## 安装到本地

```bash
install -m 0755 git/history-file-md5.sh ~/.local/bin/git-history-file-md5
```

之后可直接运行：

```bash
git-history-file-md5 -n 10 -r '(^|/)libexample\.so[^/]*$'
```