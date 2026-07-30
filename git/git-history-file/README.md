# git-history-file

## 解决的问题

在工程开发中，经常需要确认：

- 某个动态库、模型、固件文件在哪些提交中发生变化；
- 不同版本交付物是否来自同一个实体文件；
- 某个二进制文件历史版本的内容是否一致。

`git log -- path` 只能回答“哪些提交涉及这个路径”，但不能方便回答“这个文件实体如何变化”。

本工具通过 Git 的 commit/tree/blob 模型，提取文件历史变化和内容指纹。

## 使用方法

```bash
./git-history-file.sh \
    --pattern 'libexample\\.so.*' \
    --limit 10
```

参数：

- `--pattern`：文件路径正则匹配规则（必选）
- `--limit`：输出最近多少次目标文件变化
- `--sha256`：使用 SHA256 替代 MD5

## 输出说明

示例：

```text
commit: abc1234
date:   2026-07-01 10:00:00 +0800
msg:    update library

modified  8cxxxx  123456  lib/libexample.so.1
```

字段：

- commit：发生变化的提交
- hash：文件内容指纹
- size：文件大小
- path：文件路径
- status：modified / deleted

## 实现原理

Git 文件对象关系：

```
commit
  |
 tree
  |
 blob
  |
 file content
```

工具执行流程：

1. 遍历 Git 历史提交；
2. 找出真正修改目标文件的提交；
3. 获取对应 blob 内容；
4. 计算文件 hash。

## 常见误区

### 最近 N 个 commit 不等于最近 N 次文件变化

例如：

```bash
git rev-list -10 HEAD
```

只代表最近 10 个提交，其中可能没有目标文件变化。

本工具查找的是：

> 最近 N 次目标文件变化。

## 限制

当前版本：

支持：

- 文件正则匹配；
- 修改、新增、删除检测；
- 内容 hash。

暂不支持：

- 复杂 rename 追踪；
- Git LFS 对象分析；
- 二进制 ABI 差异分析。
