# DevToolkit

Practical, reusable tools for software engineering, debugging, automation, and productivity.

## Scope

This repository collects tools that are:

- reusable across projects;
- small enough to understand independently;
- documented with purpose, assumptions, usage, and failure modes;
- kept separate from project-specific business code.

## Structure

```text
DevToolkit/
├── git/       # Git history, repository inspection, migration, and cleanup tools
├── linux/     # Linux diagnostics and system utilities
├── network/   # Network, proxy, SSH, and transfer helpers
├── data/      # Dataset and file-management utilities
├── model/     # Model artifact, checksum, and deployment helpers
└── docs/      # Repository conventions and cross-tool documentation
```

Directories are created only when a real reusable tool exists; empty category scaffolding is intentionally avoided.

## Tools

### Git

- [`git/history-file-md5.sh`](git/history-file-md5.sh): list the most recent commits that actually changed files matching a regular expression, together with the MD5 values of those files after each commit.

## Tool acceptance criteria

A script should enter this repository only when it has:

1. a recurring engineering use case;
2. configurable inputs rather than hard-coded project paths;
3. explicit prerequisites and compatibility assumptions;
4. predictable output and non-zero exit codes on failure;
5. a usage example and known limitations.

## License

No license has been selected yet. Unless a license file is added, the repository remains publicly visible but does not grant general reuse rights.
