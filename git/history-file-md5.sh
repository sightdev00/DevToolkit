#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  history-file-md5.sh [-n COUNT] [-r REGEX] [REV]

List the most recent commits that actually changed files matching REGEX,
and print the MD5 of each matching file as it exists after that commit.

Options:
  -n COUNT   Number of matching commits to print. Default: 10
  -r REGEX   Extended regular expression matched against repository-relative paths.
             Default: (^|/)libhq_bsd_proc\.so\.1\.1\.0[^/]*$
  -h         Show this help.

Arguments:
  REV        Starting revision. Default: HEAD

Examples:
  history-file-md5.sh \
    -n 10 \
    -r '(^|/)libhq_bsd_proc\.so\.1\.1\.0[^/]*$'

  history-file-md5.sh \
    -n 5 \
    -r '(^|/)libexample\.so(\.[0-9]+)*$' \
    release/1.2

Notes:
  - COUNT means matching commits, not merely the latest COUNT repository commits.
  - Merge commits are inspected against each parent by using git diff-tree -m.
  - Deleted matching files are printed as DELETED and have no checksum.
EOF
}

count_limit=10
pattern='(^|/)libhq_bsd_proc\.so\.1\.1\.0[^/]*$'
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
            printf 'Error: option -%s requires an argument.\n' "$OPTARG" >&2
            usage >&2
            exit 2
            ;;
        \?)
            printf 'Error: unknown option -%s.\n' "$OPTARG" >&2
            usage >&2
            exit 2
            ;;
    esac
done
shift $((OPTIND - 1))

if (($# > 1)); then
    printf 'Error: expected at most one REV argument.\n' >&2
    usage >&2
    exit 2
fi

if (($# == 1)); then
    revision=$1
fi

if [[ ! $count_limit =~ ^[1-9][0-9]*$ ]]; then
    printf 'Error: COUNT must be a positive integer: %s\n' "$count_limit" >&2
    exit 2
fi

for command_name in git grep sort md5sum awk; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'Error: required command not found: %s\n' "$command_name" >&2
        exit 127
    fi
done

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    printf 'Error: current directory is not inside a Git repository.\n' >&2
    exit 1
}

cd "$repo_root"

git rev-parse --verify "${revision}^{commit}" >/dev/null 2>&1 || {
    printf 'Error: revision does not resolve to a commit: %s\n' "$revision" >&2
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
    printf 'No commits changed files matching: %s\n' "$pattern"
    exit 3
fi
