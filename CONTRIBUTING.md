# Contributing to ccbar

## Setup

Clone the repo and test by piping sample JSON:

```bash
echo '{"context_window":{"used_percentage":42,"context_window_size":200000,"total_input_tokens":80000,"total_output_tokens":4000},"model":"claude-sonnet-4-5","cost":{"total_cost_usd":0.12,"total_duration_ms":180000,"total_api_duration_ms":9000}}' | bash ccbar.sh
```

Override the config path to test without touching your real config:

```bash
CCBAR_CONFIG=./config.default bash ccbar.sh <<< '...'
```

## Adding a config key

Any new config key must be added in **three places**:

1. Default value assignment at the top of `ccbar.sh`
2. The `case` allowlist glob in `load_config()` (if it doesn't match an existing pattern like `SHOW_*` or `COLOR_*`)
3. `config.default` with a comment explaining the value

Config values in `config.default` must be **unquoted** (e.g., `SEPARATOR=│` not `SEPARATOR="│"`), because the safe loader reads values literally.

## Adding a widget

Widgets are rendered left-to-right in the assembly section at the bottom of `ccbar.sh`. To add a new widget:

1. Parse the JSON field using the `jv` helper
2. Add a `SHOW_*` toggle (follow the pattern of existing widgets)
3. Add a `COLOR_*` variable and build the ANSI escape
4. Append to `out` in the assembly section — position determines visual order

## Pull requests

- Test your change by piping JSON and inspecting terminal output
- Keep changes minimal — one fix or feature per PR
- If you add a runtime dependency, document it in the README requirements table

## Dependencies

Runtime: `jq`, `bc`, `git`. No build tools, no package manager. Keep it that way.
