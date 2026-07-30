# git-history-file

## 解决的问题

在工程交付中，经常需要确认：

- 某个动态库、模型、固件文件在哪些版本发生变化；
- 两次发布的二进制实体是否一致；
- 某个文件历史版本对应的真实内容是否相同。

`git log -- path` 只能回答：

> 哪些提交涉及这个路径。

但工程排障通常关心：

> 这个文件实体什么时候变化？变化后的内容是否一致？

本工具基于 Git 的 commit/tree/blob 模型，提取目标文件历史变化和内容指纹。

---

## 使用方法

```bash
./git-history-file.sh \
    --pattern 'libexample\.so.*' \
    --limit 10
```

参数：

- `--pattern`：文件路径正则匹配规则（必选）
- `--limit`：最近多少次目标文件变化
- `--sha256`：使用 SHA256 替代 MD5

---

## 输出说明

示例：

```text
commit: abc1234
date:   2026-07-01 10:00:00 +0800
msg:    update library

  modified 8cxxxx 123456 lib/libexample.so.1
```

字段：

- commit：发生目标文件变化的提交
- hash：文件内容指纹
- size：文件大小
- path：文件路径
- status：modified / deleted

---

## 实现原理

Git 中一个文件不是直接挂在 commit 上，而是：

```
commit
  |
 tree
  |
 blob
  |
 file content
```

工具流程：

1. 遍历历史 commit；
2. 判断 commit 是否修改匹配文件；
3. 获取对应 blob；
4. 计算文件 hash。

因此它关注的是：

```
Git 历史
   ↓
文件实体变化
   ↓
内容身份确认
```

---

## 常见误区

### 最近 N 个 commit 不等于最近 N 次文件变化

例如：

```bash
git rev-list -10 HEAD
```

只表示最近 10 个提交，其中可能没有目标文件变化。

本工具查找的是：

> 最近 N 次目标文件变化。

---

## 适用场景

适合：

- `.so` 动态库版本追踪；
- 模型文件版本确认；
- 固件、资源文件历史核查。

不适合：

- 判断代码逻辑是否一致；
- 分析二进制 ABI 差异；
- 替代完整发布管理系统。

---

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
