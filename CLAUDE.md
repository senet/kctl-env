# CLAUDE.md — kctl-env Runbook

> Pure Bash kubectl version manager — zero runtime dependencies, tfenv-style UX, context-aware auto-switching.

---

## Confidence Rule

**Before writing any code, always ask clarifying questions until confidence reaches >98%.**

If anything is ambiguous — intended behaviour, scope, version semantics, target OS, rollback plan — ask. One wrong assumption can break idempotency guarantees or the shim startup path. Never proceed on a >2% guess.

---

## Doc-Update Rule

**After every version bump, always update all of the following before closing the task:**

| File | What to update |
|------|---------------|
| `VERSION` | Canonical version string (e.g. `0.3.0`) |
| `CHANGELOG.md` | Move `## [Unreleased]` entries under new version header + date |
| `README.md` | Version badge, install URL (pinned tag in curl one-liner), feature notes |
| `packaging/debian/changelog` | New Debian changelog stanza (`scripts/release.sh` does this) |
| `packaging/rpm/kctl-env.spec` | `Version:` field and `%changelog` entry |

Run `make release V=<new-version>` — it handles the packaging files. The VERSION, CHANGELOG.md, and README.md updates require manual review.

---

## Project Overview

| Field | Value |
|-------|-------|
| Language | Pure Bash (no compiled code) |
| Current version | 0.2.0 |
| License | MIT |
| Remote | git@github.com:senet/kctl-env.git |
| Branching model | `feat/*`, `fix/*`, `chore/*`, `release/vX.Y.Z` → PR to `main` |

---

## Architecture

```
bin/kctl-env          CLI dispatcher (routes subcommands)
bin/kubectl           Fast shim (version resolve + exec)
libexec/
  kctl-env-common     Shared library (sourced by all scripts)
  kctl-env-install    install subcommand
  kctl-env-use        use subcommand
  kctl-env-list       list subcommand
  kctl-env-list-remote  list-remote subcommand
etc/
  kctl-env-completion.bash
  kctl-env-completion.zsh
scripts/
  release.sh          Version bump + packaging metadata automation
  smoke-wsl.sh        End-to-end integration smoke test
packaging/
  debian/             .deb build metadata
  rpm/kctl-env.spec   .rpm build spec
install.sh            Bootstrap installer (curl-pipe safe, WSL-aware)
Makefile              install / uninstall / dist / release / clean targets
VERSION               Canonical version (single source of truth)
```

### Version resolution — 4-tier priority chain (highest → lowest)

1. `$KCTL_VERSION` env var (process scope)
2. `.kubectl-version` file (walks up from `$PWD`)
3. `$KCTL_ENV_ROOT/version` (global pin, written by `kctl-env use`)
4. Auto mode → cluster cache → live server query; fallback to `latest`

### Runtime layout (`~/.kctl-env/` = `$KCTL_ENV_ROOT`)

```
bin/        kctl-env, kubectl (shim)
libexec/    core logic modules
etc/        completions
versions/   downloaded kubectl binaries  (git-ignored)
cache/      cluster-map TTL cache        (git-ignored)
version     global version pin (e.g. auto, latest, v1.33.0)
```

---

## Key Files

| File | Role |
|------|------|
| `libexec/kctl-env-common` | Shared functions, env vars, version validation, cache logic — read this first |
| `bin/kubectl` | Critical hot path — keep startup time minimal, `exec` at end |
| `install.sh` | User-facing bootstrap; SHA256 verification is mandatory for tagged releases |
| `scripts/release.sh` | Automates packaging metadata on version bump |
| `scripts/smoke-wsl.sh` | Integration test suite |
| `Makefile` | Single entry point for build/install/dist/release |
| `VERSION` | Canonical version — always update this first on a release |

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `KCTL_ENV_ROOT` | `~/.kctl-env` | Root install dir |
| `KCTL_VERSION` | — | Override kubectl version (highest priority) |
| `KCTL_ARCH` | auto-detected | Force amd64/arm64 for install |
| `KCTL_CLUSTER_TTL` | `300` | Auto-mode cache TTL (seconds) |
| `KCTL_ENV_DEBUG` | — | Set to `1` for debug logging to stderr |
| `GITHUB_TOKEN` | — | Avoids API rate limits in `list-remote` |
| `KCTL_LIST_REMOTE_MAX_PAGES` | `5` | Pagination cap for `list-remote` |
| `KCTL_ENV_AUTO_PATH` | — | `1`/`0` to control PATH auto-setup in installer |
| `KCTL_ENV_RC_FILE` | auto | Shell rc file the installer edits |
| `KCTL_ENV_SKIP_VERIFY` | — | `1` to skip SHA256 (not recommended) |

---

## Development Workflow

```bash
# 1. Feature branch
git checkout -b feat/my-feature main

# 2. Edit, then run smoke test
./scripts/smoke-wsl.sh

# 3. PR to main (checklist in .github/pull_request_template.md)
```

### Adding a subcommand

1. Create `libexec/kctl-env-<name>` (source `kctl-env-common` at top).
2. Add a `cmd_<name>()` case in `bin/kctl-env`.
3. Add completion entries in `etc/kctl-env-completion.bash` and `.zsh`.
4. Add smoke test assertions in `scripts/smoke-wsl.sh`.
5. Update `README.md` usage section and `CHANGELOG.md` Unreleased block.

### Editing the shim (`bin/kubectl`)

- Source `kctl-env-common` once at top; do not call subshells.
- End with `exec "$resolved_bin" "$@"` — this is performance-critical.
- Any validation added must be in `is_valid_version()` in `kctl-env-common`.

### Editing the shared library (`libexec/kctl-env-common`)

- All modules source this file — any change here affects all commands and the shim.
- The cluster-map cache format is: `<context-name> <version> <timestamp>`.
  Use awk string comparison only (never regex match) to avoid cache injection.
- `sort_versions_desc()` must work on both GNU sort (`-V`) and POSIX awk fallback (macOS/BSD).

---

## Testing

```bash
# Full end-to-end smoke test
./scripts/smoke-wsl.sh

# Skip network kubectl download (offline)
SKIP_KUBECTL_INSTALL=1 ./scripts/smoke-wsl.sh

# Test a specific branch
SMOKE_REF=feat/my-feature ./scripts/smoke-wsl.sh

# Debug mode
KCTL_ENV_DEBUG=1 kubectl version --client
```

No CI is configured yet. Until GitHub Actions workflows exist, run the smoke test locally before every PR.

---

## Release Workflow

> Use the `/release` Claude command to be guided step by step.

```bash
# 1. Create release branch
git checkout -b release/vX.Y.Z main

# 2. Bump version (updates VERSION, Debian changelog, RPM spec)
make release V=X.Y.Z

# 3. Manually update CHANGELOG.md — move Unreleased → [X.Y.Z] YYYY-MM-DD
# 4. Manually update README.md — badge + curl one-liner version pin

# 5. Commit, push, PR to main
git add VERSION CHANGELOG.md README.md packaging/
git commit -m "release: vX.Y.Z"

# 6. After merge, tag main
git tag -a vX.Y.Z -m "release: vX.Y.Z"
git push origin vX.Y.Z

# 7. GitHub Release: upload dist tarball + SHA256 checksum
make dist
sha256sum dist/kctl-env-X.Y.Z.tar.gz > dist/kctl-env-X.Y.Z.tar.gz.sha256
gh release create vX.Y.Z dist/kctl-env-X.Y.Z.tar.gz dist/kctl-env-X.Y.Z.tar.gz.sha256
```

---

## Security Rules

| Concern | Rule |
|---------|------|
| Path traversal | All version strings must pass `is_valid_version()` before any filesystem use |
| Cache injection | Use awk string comparison (not regex) when reading `cluster-map` |
| Install verification | SHA256 verification is **mandatory** for tagged releases; never disable for production installs |
| Curl-pipe installer | Only skip `KCTL_ENV_SKIP_VERIFY` in development/testing |

---

## Packaging

```bash
# Build Debian package
sudo apt-get install debhelper devscripts
debuild -us -uc

# Build RPM
sudo dnf install rpm-build
rpmbuild -ba packaging/rpm/kctl-env.spec

# Build tarball
make dist   # → dist/kctl-env-X.Y.Z.tar.gz
```

---

## Common Commands

```bash
make dist                        # Create release tarball
make install PREFIX=/usr/local   # System-wide install
make release V=0.3.0             # Bump version + update packaging metadata
./scripts/smoke-wsl.sh           # End-to-end integration test
KCTL_ENV_DEBUG=1 kctl-env list   # Debug a command
gh release create vX.Y.Z ...    # Publish GitHub release
```
