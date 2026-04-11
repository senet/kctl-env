# Changelog

All notable changes to this project will be documented in this file. This project adheres to Semantic Versioning.

## [Unreleased]

## [v0.2.0] - 2026-04-11
### Added
- `kctl-env list` command — show locally installed versions with active version marker
- `libexec/kctl-env-common` shared library — DRY extraction of logging, validation, version resolution, cache management, and portable sorting
- Input validation (`is_valid_version()`) in `kctl-env use` and the kubectl shim to reject path traversal and malformed version strings
- Debug logging via `KCTL_ENV_DEBUG=1` environment variable across all scripts
- Already-installed check in `kctl-env install` — skips download with informational message
- ARCHITECTURE.md with embedded SVG system diagram
- Architecture SVG diagram (`kctl_env_architecture.svg`)
- Shell completion scripts for kctl-env (Bash and Zsh)
- WSL-friendly PATH auto-setup in `install.sh` (prompt + idempotent rc update)
- WSL smoke test (`scripts/smoke-wsl.sh`)
- `grep` added to installer dependency checks
- `install.sh` bootstrap installer (installs kctl-env into `~/.kctl-env` or `$KCTL_ENV_ROOT`)
- README "Quick install" section, Environment Variables table, Troubleshooting section

### Changed
- All `libexec/` modules and the kubectl shim now source `kctl-env-common` instead of duplicating functions
- Cache updates use `awk` string comparison instead of `grep -E` to prevent regex injection
- Cache auto-prunes entries older than 10× TTL on write
- README Architecture section replaced inline ASCII diagram with SVG and link to ARCHITECTURE.md
- Portable `sort_versions_desc()` with GNU `sort -V` preferred and awk POSIX fallback

### Fixed
- `kctl-env list` handles `auto` keyword via cluster-map cache lookup
- Empty `raw_versions` guard prevents blank line in list output

## [v0.1.0] - 2026-01-07
### Added
- Initial scaffold: bin/kubectl shim with env/.kubectl-version/global/auto resolution and TTL cache
- Dispatcher: bin/kctl-env with install/use/list-remote commands
- Installer: OS/arch detection, SHA256 verification, Apple Silicon amd64 fallback via KCTL_ARCH
- Packaging scaffolds: Debian, RPM, Makefile install/uninstall/dist
- README with setup, usage, auto mode notes
- CONTRIBUTING, release script, PR template

### Changed
- Git repository initialized, branch protections configured (squash/rebase, linear history, delete branch on merge)

[v0.1.0]: https://github.com/senet/kctl-env/releases/tag/v0.1.0
[v0.2.0]: https://github.com/senet/kctl-env/releases/tag/v0.2.0

[Unreleased]: https://github.com/senet/kctl-env/compare/v0.2.0...HEAD
