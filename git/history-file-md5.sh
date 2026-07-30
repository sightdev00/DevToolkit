#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
用法：
  history-file-md5.sh [-n COUNT] [-r REGEX] [REV]

查找最近真正修改过匹配文件的提交，并输出这些文件在对应提交后的 MD5。

选项：
  -n COUNT   输出的匹配提交数量，默认：10
  -r REGEX   用于匹配仓库相对路径的扩展正则表达式。
             默认：(^|/)libexample\.so[^/]*$
  -h         显示帮助信息。

参数：
  REV        历史遍历起点，默认：HEAD

示例：
  history-file-md5.sh \
    -n 10 \
    -r '(^|/)libexample\.so\.1\.2[^/]*$'

  history-file-md5.sh \
    -n 5 \
    -r '(^|/)libsample\.so(\.[0-9]+)*$' \
    release/1.2

说明：
  - COUNT 表示修改过匹配文件的提交数，不是最近的普通提交总数。
  - merge commit 通过 git diff-tree -m 分别与父提交比较。
  - 删除的匹配文件显示为 DELETED，不输出校验值。
EOF
}

count_limit=10
pattern='(^|/)libexample\.so[^/]*$'
revision='HEAD'

while getopts ':n:r:h' option; do
    case "$option" in
        n)
            count_limit=$OPTARG
            ;;
        r)
            pattern=$OPTARG
            ;;
        h)
            usage
            exit 0
            ;;
        :)
            printf '错误：选项 -%s 缺少参数。\n' "$OPTARG" >&2
            usage >&2
            exit 2
            ;;
        \?)
            printf '错误：未知选项 -%s。\n' "$OPTARG" >&2
            usage >&2
            exit 2
            ;;
    esac
done
shift $((OPTIND - 1))

if (($# > 1)); then
    printf '错误：最多只能提供一个 REV 参数。\n' >&2
    usage >&2
    exit 2
fi

if (($# == 1)); then
    revision=$1
fi

if [[ ! $count_limit =~ ^[1-9][0-9]*$ ]]; then
    printf '错误：COUNT 必须是正整数：%s\n' "$count_limit" >&2
    exit 2
fi

for command_name in git grep sort md5sum awk; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf '错误：缺少必要命令：%s\n' "$command_name" >&2
        exit 127
    fi
done

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    printf '错误：当前目录不在 Git 仓库中。\n' >&2
    exit 1
}

cd "$repo_root"

git rev-parse --verify "${revision}^{commit}" >/dev/null 2>&1 || {
    printf '错误：REV 无法解析为提交：%s\n' "$revision" >&2
    exit 1
}

matching_commit_count=0

while IFS= read -r commit; do
    mapfile -t changed_files < <(
        git diff-tree \
            -m \
            --root \
            --no-commit-id \
            --name-only \
            -r \
            "$commit" 2>/dev/null |
        grep -E "$pattern" |
        sort -u || true
    )

    ((${#changed_files[@]} == 0)) && continue

    printf '\n%s\n' "$(git show -s --format='%h %ci %s' "$commit")"

    for file_path in "${changed_files[@]}"; do
        if git cat-file -e "$commit:$file_path" 2>/dev/null; then
            checksum=$(
                git cat-file blob "$commit:$file_path" |
                md5sum |
                awk '{print $1}'
            )
            printf '  %s  %s\n' "$checksum" "$file_path"
        else
            printf '  %-32s  %s\n' 'DELETED' "$file_path"
        fi
    done

    ((matching_commit_count += 1))
    ((matching_commit_count >= count_limit)) && break
done < <(git rev-list "$revision")

if ((matching_commit_count == 0)); then
    printf '未找到修改过匹配文件的提交：%s\n' "$pattern"
    exit 3
fi