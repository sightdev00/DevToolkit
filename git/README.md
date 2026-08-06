# Git 工具

这里保存 Git 历史、仓库检查、迁移与清理相关的可复用工具。

## 当前工具

### [`git-history-file/`](git-history-file/)

查询一组正则匹配文件在 Git 历史中的真实变化，并输出：

- 发生变化的提交；
- 新增、修改、删除或类型变化状态；
- 提交后文件内容的 SHA-256 或 MD5；
- Git blob 大小；
- 仓库相对路径。

适合动态库、模型、固件和其他二进制制品的历史核查。

```bash
bash git/git-history-file/git-history-file.sh \
  --pattern '(^|/)libexample\.so(\.[0-9]+)*$' \
  --limit 10 \
  --hash sha256
```

详细参数、输出、依赖与限制见工具目录中的 [README](git-history-file/README.md)。

## 收录边界

这里不保存：

- 单条 `git checkout`、`restore`、`log` 命令的摘抄；
- 只针对一个仓库路径或业务名称编写的临时脚本；
- GitHub 平台治理原则或仓库组织方法；
- 模型发布、ABI 判断等领域结论。

只有当 Git 操作已经形成稳定输入、可验证输出、明确失败模式和跨仓库复用价值时，才建立独立工具目录。
