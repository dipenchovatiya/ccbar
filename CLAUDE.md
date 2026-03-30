# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ccbar is a bash-only Claude Code statusline that renders a color-coded context bar and session stats. It runs as Claude Code's `statusCommand` — receiving session JSON on stdin each turn, parsing it with `jq`, and outputting a single ANSI-colored line. No Node.js, no daemon, no background process.

## Architecture

Two scripts, one config:

- **`ccbar.sh`** — the statusline renderer. Reads JSON from stdin, loads user config, queries git, assembles ANSI output via `printf "%b"`. Sections: config loading → JSON parsing → git info → bar building → widget assembly.
- **`install.sh`** — curl-based installer/uninstaller. Downloads `ccbar.sh` to `~/.claude/`, copies `config.default` to `~/.config/ccbar/config`, and sets `statusLine` in `~/.claude/settings.json`. Supports `--uninstall` and `--purge` flags. Backs up the original `statusLine` value before overwriting.
- **`config.default`** — reference config with all knobs. The safe config loader (`load_config` function in `ccbar.sh`) reads key=value pairs with a `case` allowlist — it does NOT `source` the file, to prevent code injection.

## Key Design Decisions

- **Config loading uses a `case` allowlist, not `source`** — only `SHOW_*`, `BAR_WIDTH`, `THRESHOLD_*`, `COLOR_*`, `SEPARATOR`, and `BRANCH_MAX_LEN` keys are accepted. Any change to config keys must update both `config.default` and the `case` statement in `ccbar.sh`. See `CONTRIBUTING.md` for the full checklist.
- **ANSI 256-color codes** — all colors are configured as integers (e.g., `COLOR_BRANCH=141`) and expanded into escape sequences at runtime.
- **Token formatting uses `bc`** for division (see `fmt_k` function) — `bc` is a runtime dependency alongside `jq` and `git`.
- **Model field handles multiple shapes** — the `.model` JSON field can be a plain string or an object with `display_name`/`id`. The parser tries `.model.display_name`, then `.model.id`, then `.model` as a string.
- **Install location**: script goes to `~/.claude/ccbar.sh`, config to `~/.config/ccbar/config`. The installer uses the expanded `$HOME` path (not `~`) when writing the command to settings.json.
- **Widget render order is the visual order** — widgets are appended left-to-right in the assembly section at the bottom of `ccbar.sh`. Reordering the `if` blocks changes the statusline layout.

## Expected JSON Schema

ccbar reads these fields from stdin (all optional, with fallbacks):

```
.context_window.used_percentage    → bar fill + health color
.context_window.context_window_size → token denominator (default 200000)
.context_window.total_input_tokens  → token count display
.context_window.total_output_tokens → speed calc (output tok/s) + token count
.model                             → string or {display_name, id}
.cost.total_cost_usd               → session cost
.cost.total_duration_ms            → wall-clock duration
.cost.total_api_duration_ms        → speed calc (tokens/sec)
.worktree.name                     → worktree widget (absent = hidden)
.cwd                               → folder widget (fallback: pwd)
```

## Testing Locally

Pipe sample JSON to the script to test rendering:

```bash
echo '{"context_window":{"used_percentage":42,"context_window_size":200000,"total_input_tokens":80000,"total_output_tokens":4000},"model":"claude-sonnet-4-5","cost":{"total_cost_usd":0.12,"total_duration_ms":180000,"total_api_duration_ms":9000}}' | bash ccbar.sh
```

Override config path for testing without touching the user's config:

```bash
CCBAR_CONFIG=./config.default bash ccbar.sh <<< '...'
```

Benchmark with `time`:

```bash
echo '...' | time bash ccbar.sh
```

There is no test suite — verify changes by piping JSON and inspecting terminal output.

## Gotchas

- **Config values should be bare (unquoted)** — `config.default` uses `KEY=value` without shell-style quotes. The loader strips matched surrounding quotes as a courtesy, but the canonical format is bare values: `SEPARATOR=│` not `SEPARATOR="│"`.
- **`--version` flag** — `ccbar.sh --version` prints the version string and exits. Useful for install verification.
- **CI** — `.github/workflows/shellcheck.yml` lints both scripts on push/PR to `main`.

## Runtime Dependencies

`jq` (required), `bc` (for token formatting), `git` (for branch/status widgets). All checked or used at runtime in `ccbar.sh`.
