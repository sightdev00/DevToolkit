#!/usr/bin/env bash

set -euo pipefail

limit=10
pattern=''
hash_algorithm='sha256'
revision='HEAD'
revision_set=false

usage() {
    cat <<'EOF'
用法：
  git-history-file [选项] [REV]

查找最近若干个真正修改过匹配文件的提交，并输出文件在对应提交后的
Git 状态、内容校验值、大小和仓库相对路径。

选项：
  -p, --pattern REGEX   文件路径扩展正则表达式，必选。
  -n, --limit COUNT     输出的匹配提交数量，默认：10。
      --hash ALG        内容校验算法：sha256 或 md5，默认：sha256。
      --sha256          等价于 --hash sha256。
      --md5             等价于 --hash md5。
  -r, --revision REV    历史遍历起点，默认：HEAD。
  -h, --help            显示帮助。

REV 也可以作为唯一的位置参数提供。

示例：
  git-history-file \
    --pattern '(^|/)libexample\.so(\.[0-9]+)*$' \
    --limit 10

  git-history-file \
    --pattern '(^|/)models/.*\.onnx$' \
    --limit 5 \
    --hash sha256 \
    --revision release/1.2

退出码：
  0    查询成功。
  1    仓库、版本或 Git 对象读取失败。
  2    参数错误。
  3    没有找到匹配的文件变化。
  127  缺少依赖命令。
EOF
}

fail_usage() {
    printf '错误：%s\n\n' "$1" >&2
    usage >&2
    exit 2
}

while (($# > 0)); do
    case "$1" in
        -p|--pattern)
            (($# >= 2)) || fail_usage "$1 缺少参数"
            pattern=$2
            shift 2
            ;;
        -n|--limit)
            (($# >= 2)) || fail_usage "$1 缺少参数"
            limit=$2
            shift 2
            ;;
        --hash)
            (($# >= 2)) || fail_usage "$1 缺少参数"
            hash_algorithm=$2
            shift 2
            ;;
        --sha256)
            hash_algorithm='sha256'
            shift
            ;;
        --md5)
            hash_algorithm='md5'
            shift
            ;;
        -r|--revision)
            (($# >= 2)) || fail_usage "$1 缺少参数"
            revision=$2
            revision_set=true
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            fail_usage "未知选项：$1"
            ;;
        *)
            if [[ $revision_set == true ]]; then
                fail_usage '只能提供一个 REV'
            fi
            revision=$1
            revision_set=true
            shift
            ;;
    esac
done

if (($# > 0)); then
    fail_usage '只能提供一个 REV'
fi

[[ -n $pattern ]] || fail_usage '--pattern 为必选参数'
[[ $limit =~ ^[1-9][0-9]*$ ]] || fail_usage '--limit 必须是正整数'

case "$hash_algorithm" in
    sha256)
        hash_command='sha256sum'
        ;;
    md5)
        hash_command='md5sum'
        ;;
    *)
        fail_usage "不支持的校验算法：$hash_algorithm"
        ;;
esac

if ((BASH_VERSINFO[0] < 4)); then
    printf '错误：需要 Bash 4 或更高版本。\n' >&2
    exit 127
fi

for command_name in git awk sort "$hash_command"; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf '错误：缺少必要命令：%s\n' "$command_name" >&2
        exit 127
    fi
done

set +e
[[ '' =~ $pattern ]]
regex_status=$?
set -e
if ((regex_status == 2)); then
    fail_usage "无效的扩展正则表达式：$pattern"
fi

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    printf '错误：当前目录不在 Git 仓库中。\n' >&2
    exit 1
}
cd "$repo_root"

git rev-parse --verify "${revision}^{commit}" >/dev/null 2>&1 || {
    printf '错误：REV 无法解析为提交：%s\n' "$revision" >&2
    exit 1
}

status_name() {
    case "$1" in
        A) printf 'added' ;;
        M) printf 'modified' ;;
        D) printf 'deleted' ;;
        T) printf 'typechange' ;;
        U) printf 'unmerged' ;;
        X) printf 'unknown' ;;
        B) printf 'broken' ;;
        *) printf 'changed(%s)' "$1" ;;
    esac
}

matching_commit_count=0

while IFS= read -r commit; do
    unset changed_status
    declare -A changed_status=()

    while IFS= read -r -d '' git_status && IFS= read -r -d '' file_path; do
        if [[ $file_path =~ $pattern ]]; then
            changed_status["$file_path"]=$git_status
        fi
    done < <(
        git diff-tree \
            -m \
            --root \
            --no-commit-id \
            --name-status \
            --no-renames \
            -r \
            -z \
            "$commit" 2>/dev/null
    )

    ((${#changed_status[@]} == 0)) && continue

    printf '\ncommit: %s\n' "$(git show -s --format='%h' "$commit")"
    printf 'date:   %s\n' "$(git show -s --format='%ci' "$commit")"
    printf 'msg:    %s\n\n' "$(git show -s --format='%s' "$commit")"

    mapfile -t sorted_paths < <(
        printf '%s\n' "${!changed_status[@]}" | LC_ALL=C sort
    )

    for file_path in "${sorted_paths[@]}"; do
        git_status=${changed_status[$file_path]}
        display_status=$(status_name "$git_status")

        if [[ $git_status == D ]] || ! git cat-file -e "$commit:$file_path" 2>/dev/null; then
            printf '  %-10s %-64s %-12s %s\n' \
                "$display_status" '-' '-' "$file_path"
            continue
        fi

        blob=$(git rev-parse "$commit:$file_path")
        checksum=$(
            git cat-file blob "$blob" |
                "$hash_command" |
                awk '{print $1}'
        )
        size=$(git cat-file -s "$blob")

        printf '  %-10s %-64s %-12s %s\n' \
            "$display_status" "$checksum" "$size" "$file_path"
    done

    ((matching_commit_count += 1))
    ((matching_commit_count >= limit)) && break
done < <(git rev-list "$revision")

if ((matching_commit_count == 0)); then
    printf '未找到修改过匹配文件的提交：%s\n' "$pattern"
    exit 3
fi
