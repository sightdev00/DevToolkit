#!/usr/bin/env bash
set -euo pipefail

LIMIT=10
PATTERN=""
HASH_CMD="md5sum"

usage() {
    cat <<'EOF'
Usage:
  git-history-file.sh [options]

Options:
  -n, --limit N          Number of latest file changes (default: 10)
  -p, --pattern REGEX    File path regex pattern (required)
  --sha256               Use sha256 instead of md5
  -h, --help             Show help

Example:
  ./git-history-file.sh \
      --pattern 'libexample\.so.*' \
      --limit 10
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--limit)
            LIMIT="$2"; shift 2 ;;
        -p|--pattern)
            PATTERN="$2"; shift 2 ;;
        --sha256)
            HASH_CMD="sha256sum"; shift ;;
        -h|--help)
            usage; exit 0 ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 1 ;;
    esac
done

if [[ -z "$PATTERN" ]]; then
    echo "Error: --pattern is required" >&2
    usage
    exit 1
fi

cd "$(git rev-parse --show-toplevel)"

count=0

# Traverse commits, but only output commits that actually modify matched files.
# Note: merge commits may contain duplicate paths, therefore sort uniquely.
while read -r commit; do
    mapfile -t files < <(
        git diff-tree -m --root --no-commit-id --name-only -r "$commit" |
        sort -u |
        grep -E "$PATTERN" || true
    )

    [[ ${#files[@]} -eq 0 ]] && continue

    echo
    git show -s --format='commit: %h%ndate:   %ci%nmsg:    %s' "$commit"

    for file in "${files[@]}"; do
        if git cat-file -e "$commit:$file" 2>/dev/null; then
            blob=$(git rev-parse "$commit:$file")
            hash=$(git cat-file blob "$blob" | $HASH_CMD | awk '{print $1}')
            size=$(git cat-file -s "$blob")
            status="modified"
        else
            hash="-"
            size="-"
            status="deleted"
        fi

        printf "  %-8s %-40s %-12s %s\n" "$status" "$hash" "$size" "$file"
    done

    count=$((count + 1))
    [[ $count -ge $LIMIT ]] && break

done < <(git rev-list HEAD)
