# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ccbar is a bash-only Claude Code statusline that renders a color-coded context bar and session stats. It runs as Claude Code's `statusCommand` — receiving session JSON on stdin each turn, parsing it with `jq`, and outputting a single ANSI-colored line. No Node.js, no daemon, no background process.

## Architecture

Two scripts, one config:

- **`ccbar.sh`** — the statusline renderer. Reads JSON from stdin, loads user config, queries git, assembles ANSI output via `printf "%b"`. Sections: config loading → JSON parsing → git info → bar building → widget assembly.
- **`install.sh`** — curl-based installer/uninstaller. Downloads `ccbar.sh` to `~/.claude/`, copies `config.default` to `~/.config/ccbar/config`, and sets `statusLine` in `~/.claude/settings.json`. Supports `--uninstall` and `--purge` flags. Backs up the original `statusLine` value before overwriting.
- **`config.default`** — reference config with all knobs. The safe config loader in `ccbar.sh` (line 51) reads key=value pairs with a `case` allowlist — it does NOT `source` the file, to prevent code injection.

## Key Design Decisions

- **Config loading uses a `case` allowlist, not `source`** — only `SHOW_*`, `BAR_WIDTH`, `THRESHOLD_*`, `COLOR_*`, `SEPARATOR`, and `BRANCH_MAX_LEN` keys are accepted. Any change to config keys must update both `config.default` and the `case` statement in `ccbar.sh:57`.
- **ANSI 256-color codes** — all colors are configured as integers (e.g., `COLOR_BRANCH=141`) and expanded into escape sequences at runtime.
- **Token formatting uses `bc`** for division (see `fmt_k` function) — `bc` is a runtime dependency alongside `jq` and `git`.
- **Install location**: script goes to `~/.claude/ccbar.sh`, config to `~/.config/ccbar/config`. The installer hardcodes `~/.claude/ccbar.sh` as the command path in settings.json.

## Testing Locally

Pipe sample JSON to the script to test rendering:

```bash
echo '{"context_window":{"used_percentage":42,"context_window_size":200000,"total_input_tokens":80000,"total_output_tokens":4000},"model":"claude-sonnet-4-5","cost":{"total_cost_usd":0.12,"total_duration_ms":180000,"total_api_duration_ms":9000}}' | bash ccbar.sh
```

Benchmark with `time`:

```bash
echo '...' | time bash ccbar.sh
```

There is no test suite — verify changes by piping JSON and inspecting terminal output.

## Runtime Dependencies

`jq` (required), `bc` (for token formatting), `git` (for branch/status widgets). All checked or used at runtime in `ccbar.sh`.
