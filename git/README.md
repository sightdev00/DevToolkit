# Git tools

## `history-file-md5.sh`

Find the most recent commits that actually changed files whose repository-relative paths match an extended regular expression, then print each matching file's MD5 as stored in that commit.

## Why this exists

A plain loop over `git rev-list -n N HEAD` answers a different question: it checks the latest `N` repository commits, most of which may not have touched the target artifact. This tool instead walks history until it finds `N` commits that changed the requested files.

It also avoids three common failures:

- shell wildcards are not expanded inside historical Git trees;
- running inside a repository subdirectory can lose the repository-relative path needed by `git cat-file`;
- failed `git cat-file` pipelines can misleadingly produce the MD5 of empty input (`d41d8cd98f00b204e9800998ecf8427e`).

## Requirements

- Bash 4 or newer (`mapfile` is used)
- Git
- GNU `grep`, `sort`, `md5sum`, and `awk`

For macOS, install GNU coreutils and either adapt `md5sum` to `gmd5sum` or provide a compatible command.

## Usage

```bash
bash git/history-file-md5.sh \
  -n 10 \
  -r '(^|/)libhq_bsd_proc\.so\.1\.1\.0[^/]*$'
```

Run it from any directory inside the target Git repository. The script automatically changes to the repository root.

To inspect another revision:

```bash
bash git/history-file-md5.sh \
  -n 5 \
  -r '(^|/)libexample\.so(\.[0-9]+)*$' \
  release/1.2
```

## Output

```text
b31506e 2026-07-03 16:51:00 +0800 update library
  7af6...  AiLibGather/libaialgo_all/libhq_bsd_proc.so.1.1.0.6
```

Deleted matching files are shown as:

```text
  DELETED                           path/to/libexample.so.1
```

## Semantics and limitations

- `-n` counts commits that changed matching files, not all traversed commits.
- Paths are matched with `grep -E`, so `-r` accepts an extended regular expression, not a shell glob.
- A merge commit can appear when its result differs from at least one parent because `git diff-tree -m` is used.
- MD5 is suitable for quick identity comparison, not cryptographic integrity or adversarial verification. Use SHA-256 for security-sensitive checks.
- The checksum represents the file after the commit. A deletion has no post-commit checksum.

## Install locally

```bash
install -m 0755 git/history-file-md5.sh ~/.local/bin/git-history-file-md5
```

Then run:

```bash
git-history-file-md5 -n 10 -r '(^|/)libexample\.so[^/]*$'
```
