# /new-feature — Add a Feature to kctl-env

Guide me through adding a new feature following project conventions.

## Before starting — confidence gate

Ask questions until >98% confident about:
- Feature name (becomes the branch name `feat/<name>` and command name if a subcommand)
- Whether it is: a new subcommand, a shim change, a shared-library change, an installer change, or a docs-only change
- Expected user-facing behaviour (exact CLI invocation and output)
- Target OS/shell scope (Linux only, macOS too, WSL-specific, all?)
- Any environment variables it will read or write
- Whether it touches the shim hot path (startup time implications)

Do not write any code until ambiguity is <2%.

## Implementation checklist

### For a new subcommand

1. **Branch**: `git checkout -b feat/<name> main`
2. **Shared lib**: Add helper functions to `libexec/kctl-env-common` (if needed)
3. **Module**: Create `libexec/kctl-env-<name>` — source `kctl-env-common` at top
4. **Dispatcher**: Add `cmd_<name>()` case in `bin/kctl-env`
5. **Completions**: Add subcommand to both `etc/kctl-env-completion.bash` and `etc/kctl-env-completion.zsh`
6. **Smoke test**: Add assertions to `scripts/smoke-wsl.sh`
7. **Docs**: Update `README.md` usage section
8. **Changelog**: Add entry under `## [Unreleased]` in `CHANGELOG.md`

### For a shim change (`bin/kubectl`)

- Keep the critical path minimal — no subshells, no extra forks
- End with `exec "$resolved_bin" "$@"` — never return from main
- Any new validation goes in `is_valid_version()` in `kctl-env-common`
- Measure startup time before and after: `time kubectl version --client`

### For a shared-library change (`libexec/kctl-env-common`)

- All 5 modules + the shim source this file — test all affected code paths
- Cache writes must use awk string comparison (not regex) to prevent injection
- `sort_versions_desc()` must remain dual-mode: GNU `sort -V` + POSIX awk fallback
- Run smoke test after every edit

### For an installer change (`install.sh`)

- Test with: `bash install.sh` and curl-pipe simulation
- WSL detection uses `/proc/version` — do not break this
- SHA256 verification must remain mandatory for tagged releases
- PATH marker block must remain idempotent (re-run must not duplicate lines)

## Security checklist (required before PR)

- [ ] All new version strings validated by `is_valid_version()` before filesystem use
- [ ] No regex used in cache reads/writes (awk string comparison only)
- [ ] No eval or unquoted variable expansion with user-controlled input
- [ ] No new external process without fallback or error handling

## After implementation

Run smoke test:
```bash
./scripts/smoke-wsl.sh
```

Then open PR using the template in `.github/pull_request_template.md`.
